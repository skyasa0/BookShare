//
//  BookDraft.swift
//  BookShare
//
//  The editable draft AddBookView binds to. Starts life pre-filled from
//  `BookMetadata` (see `BookDraft.init(prefilledFrom:)`), then every field is
//  user-editable per the BR-01 flow.
//

import Foundation

struct BookDraft: Identifiable, Equatable, Hashable {
    let id: UUID
    var isbn: ISBN

    // Editable, auto-filled fields
    var title: String
    var authors: [String]
    var publisher: String?
    var publicationYear: String?
    var language: String?
    var pageCount: Int?
    var description: String
    var genre: String?
    var thumbnailURL: URL?
    var highResCoverURL: URL?

    // User-supplied, never auto-filled
    var edition: String?
    var condition: BookCondition
    var listingType: ListingType
    var price: Decimal?
    var pickupLocationNote: String?
    var notes: String?
    var photoIdentifiers: [String] // local PHAsset / file identifiers, uploaded on publish
    var isAvailable: Bool

    init(
        id: UUID = UUID(),
        isbn: ISBN,
        title: String = "",
        authors: [String] = [],
        publisher: String? = nil,
        publicationYear: String? = nil,
        language: String? = nil,
        pageCount: Int? = nil,
        description: String = "",
        genre: String? = nil,
        thumbnailURL: URL? = nil,
        highResCoverURL: URL? = nil,
        edition: String? = nil,
        condition: BookCondition = .good,
        listingType: ListingType = .borrow,
        price: Decimal? = nil,
        pickupLocationNote: String? = nil,
        notes: String? = nil,
        photoIdentifiers: [String] = [],
        isAvailable: Bool = true
    ) {
        self.id = id
        self.isbn = isbn
        self.title = title
        self.authors = authors
        self.publisher = publisher
        self.publicationYear = publicationYear
        self.language = language
        self.pageCount = pageCount
        self.description = description
        self.genre = genre
        self.thumbnailURL = thumbnailURL
        self.highResCoverURL = highResCoverURL
        self.edition = edition
        self.condition = condition
        self.listingType = listingType
        self.price = price
        self.pickupLocationNote = pickupLocationNote
        self.notes = notes
        self.photoIdentifiers = photoIdentifiers
        self.isAvailable = isAvailable
    }

    /// Builds a draft pre-populated from fetched metadata. Everything here
    /// remains editable in the form — this just saves the user from typing it.
    static func prefilled(from metadata: BookMetadata, isbn: ISBN) -> BookDraft {
        let year = metadata.publicationDate.flatMap { dateString -> String? in
            String(dateString.prefix(4))
        }

        return BookDraft(
            isbn: isbn,
            title: metadata.title,
            authors: metadata.authors,
            publisher: metadata.publisher,
            publicationYear: year,
            language: metadata.language,
            pageCount: metadata.pageCount,
            description: metadata.description ?? "",
            genre: metadata.categories.first,
            thumbnailURL: metadata.thumbnailURL,
            highResCoverURL: metadata.highResCoverURL ?? metadata.thumbnailURL
        )
    }

    /// Deterministic fallback spine color for a title, used when cover art is
    /// missing or fails to load (mirrors the SampleData palette).
    static func placeholderHex(for title: String) -> String {
        let palette = ["8E6F4E", "6B4A3A", "55663F", "3E5266", "7C5A9B", "9A7B3F", "B4632A"]
        let index = abs(title.hashValue) % palette.count
        return palette[index]
    }
}

enum ListingType: String, CaseIterable, Identifiable, Codable {
    case borrow
    case rent
    case sell
    case exchange
    case donate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .borrow: "Borrow"
        case .rent: "Rent"
        case .sell: "Sell"
        case .exchange: "Exchange"
        case .donate: "Donate"
        }
    }

    /// Whether this listing type needs a price field in the form.
    var requiresPrice: Bool {
        switch self {
        case .rent, .sell: true
        case .borrow, .exchange, .donate: false
        }
    }

    var systemImage: String {
        switch self {
        case .borrow: "arrow.triangle.2.circlepath"
        case .rent: "clock.arrow.circlepath"
        case .sell: "tag"
        case .exchange: "arrow.left.arrow.right"
        case .donate: "heart"
        }
    }
}

enum BookCondition: String, CaseIterable, Identifiable, Codable {
    case new
    case likeNew
    case good
    case fair
    case worn

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .new: "New"
        case .likeNew: "Like New"
        case .good: "Good"
        case .fair: "Fair"
        case .worn: "Worn"
        }
    }

    /// Postgres `book_condition` enum value (snake_case).
    var dbValue: String {
        switch self {
        case .new: "new"
        case .likeNew: "like_new"
        case .good: "good"
        case .fair: "fair"
        case .worn: "worn"
        }
    }
}
