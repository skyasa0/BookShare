//
//  BookMetadata.swift
//  BookShare
//
//  The normalized shape every provider (Google Books, Open Library, Internet
//  Archive, local cache) maps its response into. AddBookView only ever reads
//  from this type — it never touches a provider's raw JSON.
//

import Foundation

struct BookMetadata: Codable, Equatable, Sendable {
    let isbn: ISBNCodablePayload
    var title: String
    var subtitle: String?
    var authors: [String]
    var publisher: String?
    var publicationDate: String?
    var language: String?
    var pageCount: Int?
    var description: String?
    var categories: [String]
    var subjects: [String]

    var thumbnailURL: URL?
    var highResCoverURL: URL?

    var averageRating: Double?
    var ratingsCount: Int?
    var previewLink: URL?

    /// Which provider ultimately satisfied the fetch, surfaced only for
    /// debugging/telemetry — never shown to the user.
    var source: Provider

    enum Provider: String, Codable, Sendable {
        case googleBooks
        case openLibrary
        case internetArchive
        case cache
    }
}

/// `ISBN` itself isn't `Codable` in a JSON-friendly way we'd want to persist
/// (it's fine, but keeping the cache format decoupled from the validator's
/// internal shape means we can change ISBN's internals without a cache
/// migration). This is the on-disk/cache-safe representation.
struct ISBNCodablePayload: Codable, Equatable, Sendable {
    let isbn13: String
    let isbn10: String?

    init(_ isbn: ISBN) {
        self.isbn13 = isbn.isbn13
        self.isbn10 = isbn.isbn10
    }

    var asISBN: ISBN? { ISBN(raw: isbn13) }
}
