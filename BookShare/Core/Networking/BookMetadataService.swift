//
//  BookMetadataService.swift
//  BookShare
//
//  Orchestrates metadata lookup across providers with automatic fallback:
//  Google Books -> Open Library -> Internet Archive -> local cache.
//  Every provider maps into the same `BookMetadata` shape, so callers never
//  see a provider-specific type.
//

import Foundation

// MARK: - Provider protocol

protocol BookMetadataProvider: Sendable {
    var name: BookMetadata.Provider { get }
    func fetch(isbn: ISBN) async throws -> BookMetadata
}

enum BookMetadataError: Error, Equatable {
    case notFound
    case invalidResponse
    case network(String)
    case allProvidersFailed
}

// MARK: - Orchestrator

actor BookMetadataService {

    private let providers: [BookMetadataProvider]
    private let cache: BookCacheService
    private var inFlight: [String: Task<BookMetadata, Error>] = [:]

    init(
        providers: [BookMetadataProvider] = [
            GoogleBooksProvider(),
            OpenLibraryProvider(),
            InternetArchiveProvider()
        ],
        cache: BookCacheService = .shared
    ) {
        self.providers = providers
        self.cache = cache
    }

    /// Fetches metadata for an ISBN, trying providers in priority order and
    /// falling back to the next on any failure. Deduplicates concurrent
    /// requests for the same ISBN (e.g. a duplicate scan firing mid-fetch)
    /// so we never issue two network round-trips for one code.
    func fetchBook(isbn: ISBN) async throws -> BookMetadata {
        if let existing = inFlight[isbn.isbn13] {
            return try await existing.value
        }

        let task = Task<BookMetadata, Error> { [providers, cache] in
            if let cached = await cache.metadata(for: isbn) {
                return cached
            }

            var lastError: Error = BookMetadataError.allProvidersFailed
            for provider in providers {
                do {
                    let metadata = try await provider.fetch(isbn: isbn)
                    await cache.store(metadata, for: isbn)
                    return metadata
                } catch {
                    lastError = error
                    continue // fall through to the next provider
                }
            }
            throw lastError
        }

        inFlight[isbn.isbn13] = task
        defer { inFlight[isbn.isbn13] = nil }
        return try await task.value
    }

    /// Cancels any in-flight fetch for an ISBN — used when a new scan
    /// supersedes a request that hasn't resolved yet.
    func cancel(isbn: ISBN) {
        inFlight[isbn.isbn13]?.cancel()
        inFlight[isbn.isbn13] = nil
    }

    func cancelAll() {
        inFlight.values.forEach { $0.cancel() }
        inFlight.removeAll()
    }
}

// MARK: - Google Books

struct GoogleBooksProvider: BookMetadataProvider {
    let name: BookMetadata.Provider = .googleBooks

    func fetch(isbn: ISBN) async throws -> BookMetadata {
        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")!
        components.queryItems = [URLQueryItem(name: "q", value: "isbn:\(isbn.isbn13)")]
        guard let url = components.url else { throw BookMetadataError.invalidResponse }

        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response)

        let decoded = try JSONDecoder().decode(GoogleBooksResponse.self, from: data)
        guard let item = decoded.items?.first else { throw BookMetadataError.notFound }
        let info = item.volumeInfo

        return BookMetadata(
            isbn: ISBNCodablePayload(isbn),
            title: info.title ?? "Untitled",
            subtitle: info.subtitle,
            authors: info.authors ?? [],
            publisher: info.publisher,
            publicationDate: info.publishedDate,
            language: info.language,
            pageCount: info.pageCount,
            description: info.description,
            categories: info.categories ?? [],
            subjects: [],
            thumbnailURL: info.imageLinks?.thumbnail.flatMap { URL(string: Self.upgradedToHTTPS($0)) },
            highResCoverURL: (info.imageLinks?.extraLarge ?? info.imageLinks?.large ?? info.imageLinks?.thumbnail)
                .flatMap { URL(string: Self.upgradedToHTTPS($0)) },
            averageRating: info.averageRating,
            ratingsCount: info.ratingsCount,
            previewLink: item.volumeInfo.previewLink.flatMap { URL(string: $0) },
            source: .googleBooks
        )
    }

    /// Google Books image links come back as http:// — force https since we
    /// only ever issue secure requests.
    private static func upgradedToHTTPS(_ urlString: String) -> String {
        urlString.replacingOccurrences(of: "http://", with: "https://")
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw BookMetadataError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw BookMetadataError.network("Google Books returned \(http.statusCode)")
        }
    }
}

private struct GoogleBooksResponse: Decodable {
    let items: [Item]?

    struct Item: Decodable {
        let volumeInfo: VolumeInfo
    }

    struct VolumeInfo: Decodable {
        let title: String?
        let subtitle: String?
        let authors: [String]?
        let publisher: String?
        let publishedDate: String?
        let description: String?
        let pageCount: Int?
        let categories: [String]?
        let averageRating: Double?
        let ratingsCount: Int?
        let language: String?
        let previewLink: String?
        let imageLinks: ImageLinks?
    }

    struct ImageLinks: Decodable {
        let thumbnail: String?
        let large: String?
        let extraLarge: String?
    }
}

// MARK: - Open Library

struct OpenLibraryProvider: BookMetadataProvider {
    let name: BookMetadata.Provider = .openLibrary

    func fetch(isbn: ISBN) async throws -> BookMetadata {
        let url = URL(string: "https://openlibrary.org/isbn/\(isbn.isbn13).json")!
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response)

        let decoded = try JSONDecoder().decode(OpenLibraryBook.self, from: data)

        // Author names require a second round-trip against /authors/{key}.json;
        // fetched concurrently and best-effort (a missing author name shouldn't
        // fail the whole lookup).
        let authorNames = await withTaskGroup(of: String?.self) { group in
            for authorRef in decoded.authors ?? [] {
                group.addTask { try? await Self.fetchAuthorName(key: authorRef.key) }
            }
            var names: [String] = []
            for await name in group {
                if let name { names.append(name) }
            }
            return names
        }

        let coverId = decoded.covers?.first
        let thumbnail = coverId.flatMap { URL(string: "https://covers.openlibrary.org/b/id/\($0)-M.jpg") }
        let highRes = coverId.flatMap { URL(string: "https://covers.openlibrary.org/b/id/\($0)-L.jpg") }

        return BookMetadata(
            isbn: ISBNCodablePayload(isbn),
            title: decoded.title ?? "Untitled",
            subtitle: decoded.subtitle,
            authors: authorNames,
            publisher: decoded.publishers?.first,
            publicationDate: decoded.publishDate,
            language: decoded.languages?.first?.key.replacingOccurrences(of: "/languages/", with: ""),
            pageCount: decoded.numberOfPages,
            description: decoded.description?.value ?? decoded.descriptionString,
            categories: decoded.subjects ?? [],
            subjects: decoded.subjects ?? [],
            thumbnailURL: thumbnail,
            highResCoverURL: highRes,
            averageRating: nil,
            ratingsCount: nil,
            previewLink: URL(string: "https://openlibrary.org\(decoded.key ?? "")"),
            source: .openLibrary
        )
    }

    private static func fetchAuthorName(key: String) async throws -> String? {
        guard let url = URL(string: "https://openlibrary.org\(key).json") else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response)
        let author = try JSONDecoder().decode(OpenLibraryAuthor.self, from: data)
        return author.name
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw BookMetadataError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 404 { throw BookMetadataError.notFound }
            throw BookMetadataError.network("Open Library returned \(http.statusCode)")
        }
    }
}

private struct OpenLibraryBook: Decodable {
    let key: String?
    let title: String?
    let subtitle: String?
    let publishers: [String]?
    let publishDate: String?
    let numberOfPages: Int?
    let subjects: [String]?
    let covers: [Int]?
    let authors: [AuthorRef]?
    let languages: [LanguageRef]?
    let description: DescriptionValue?

    /// Some records use a bare string instead of the {value: ...} object form.
    private enum CodingKeys: String, CodingKey {
        case key, title, subtitle, publishers, subjects, covers, authors, languages, description
        case publishDate = "publish_date"
        case numberOfPages = "number_of_pages"
    }

    var descriptionString: String? {
        nil // reserved for the bare-string decode path if a future record shape needs it
    }

    struct AuthorRef: Decodable {
        let key: String
    }

    struct LanguageRef: Decodable {
        let key: String
    }

    struct DescriptionValue: Decodable {
        let value: String?

        init(from decoder: Decoder) throws {
            if let container = try? decoder.singleValueContainer(), let string = try? container.decode(String.self) {
                value = string
            } else {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                value = try container.decodeIfPresent(String.self, forKey: .value)
            }
        }

        enum CodingKeys: String, CodingKey { case value }
    }
}

private struct OpenLibraryAuthor: Decodable {
    let name: String?
}

// MARK: - Internet Archive

struct InternetArchiveProvider: BookMetadataProvider {
    let name: BookMetadata.Provider = .internetArchive

    func fetch(isbn: ISBN) async throws -> BookMetadata {
        // Internet Archive's Open Library-adjacent "Books" API keys metadata
        // lookups by ISBN through the same advancedsearch surface.
        var components = URLComponents(string: "https://archive.org/advancedsearch.php")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "isbn:\(isbn.isbn13)"),
            URLQueryItem(name: "fl[]", value: "identifier"),
            URLQueryItem(name: "fl[]", value: "title"),
            URLQueryItem(name: "fl[]", value: "creator"),
            URLQueryItem(name: "fl[]", value: "publisher"),
            URLQueryItem(name: "fl[]", value: "date"),
            URLQueryItem(name: "fl[]", value: "description"),
            URLQueryItem(name: "rows", value: "1"),
            URLQueryItem(name: "output", value: "json")
        ]
        guard let url = components.url else { throw BookMetadataError.invalidResponse }

        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response)

        let decoded = try JSONDecoder().decode(ArchiveResponse.self, from: data)
        guard let doc = decoded.response.docs.first else { throw BookMetadataError.notFound }

        let thumbnail = URL(string: "https://archive.org/services/img/\(doc.identifier)")

        return BookMetadata(
            isbn: ISBNCodablePayload(isbn),
            title: doc.title ?? "Untitled",
            subtitle: nil,
            authors: doc.creator.map { [$0] } ?? [],
            publisher: doc.publisher,
            publicationDate: doc.date,
            language: nil,
            pageCount: nil,
            description: doc.description,
            categories: [],
            subjects: [],
            thumbnailURL: thumbnail,
            highResCoverURL: thumbnail,
            averageRating: nil,
            ratingsCount: nil,
            previewLink: URL(string: "https://archive.org/details/\(doc.identifier)"),
            source: .internetArchive
        )
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw BookMetadataError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw BookMetadataError.network("Internet Archive returned \(http.statusCode)")
        }
    }
}

private struct ArchiveResponse: Decodable {
    let response: ResponseBody
    struct ResponseBody: Decodable {
        let docs: [Doc]
    }
    struct Doc: Decodable {
        let identifier: String
        let title: String?
        let creator: String?
        let publisher: String?
        let date: String?
        let description: String?
    }
}
