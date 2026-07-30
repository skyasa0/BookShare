//
//  ISBN.swift
//  BookShare
//
//  Value type representing a validated ISBN. Construction always goes
//  through `ISBN.init?(raw:)`, so any `ISBN` in the app is guaranteed
//  checksum-valid and normalized to ISBN-13.
//

import Foundation

struct ISBN: Hashable, Codable, Sendable {

    /// Always normalized to 13 digits, no hyphens (e.g. "9780134685991").
    let isbn13: String

    /// The original 10-digit form, if the scanned/typed value was ISBN-10.
    let isbn10: String?

    /// Cache key + display value.
    var value: String { isbn13 }

    init?(raw: String) {
        guard let normalized = ISBNValidator.normalize(raw) else { return nil }

        switch normalized.count {
        case 13:
            guard ISBNValidator.isValidISBN13(normalized) else { return nil }
            self.isbn13 = normalized
            self.isbn10 = ISBNValidator.isbn13ToISBN10(normalized)

        case 10:
            guard ISBNValidator.isValidISBN10(normalized) else { return nil }
            guard let converted = ISBNValidator.isbn10ToISBN13(normalized) else { return nil }
            self.isbn13 = converted
            self.isbn10 = normalized

        default:
            return nil
        }
    }

    /// Hyphenated form for display, best-effort (groups aren't always knowable without
    /// the full range table, so this only separates the prefix/check digit).
    var displayFormatted: String {
        guard isbn13.count == 13 else { return isbn13 }
        let chars = Array(isbn13)
        return "\(String(chars[0...2]))-\(String(chars[3...12]))"
    }
}
