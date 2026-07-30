//
//  ISBNValidator.swift
//  BookShare
//
//  Pure, side-effect-free ISBN logic. No networking, no UIKit — this is the
//  thing pgTAP-equivalent unit tests should hammer, since a bad checksum here
//  means a bad barcode scan somewhere upstream.
//

import Foundation

enum ISBNValidator {

    /// Strips everything but digits and a trailing "X" (valid in ISBN-10 check digits),
    /// uppercased. Returns nil if what's left isn't 10 or 13 characters.
    static func normalize(_ raw: String) -> String? {
        let allowed = raw.uppercased().filter { $0.isNumber || $0 == "X" }
        guard allowed.count == 10 || allowed.count == 13 else { return nil }
        return allowed
    }

    // MARK: - Checksums

    static func isValidISBN13(_ value: String) -> Bool {
        guard value.count == 13, value.allSatisfy(\.isNumber) else { return false }
        let digits = value.compactMap { $0.wholeNumberValue }
        let sum = digits.enumerated().reduce(0) { partial, pair in
            let (index, digit) = pair
            return partial + digit * (index % 2 == 0 ? 1 : 3)
        }
        return sum % 10 == 0
    }

    static func isValidISBN10(_ value: String) -> Bool {
        guard value.count == 10 else { return false }
        var sum = 0
        for (index, char) in value.enumerated() {
            let weight = 10 - index
            if char == "X", index == 9 {
                sum += 10 * weight
            } else if let digit = char.wholeNumberValue {
                sum += digit * weight
            } else {
                return false
            }
        }
        return sum % 11 == 0
    }

    // MARK: - Conversion

    /// ISBN-10 -> ISBN-13 by prefixing "978" and recomputing the check digit.
    static func isbn10ToISBN13(_ isbn10: String) -> String? {
        guard isbn10.count == 10 else { return nil }
        let core = "978" + isbn10.prefix(9)
        guard let checkDigit = isbn13CheckDigit(for: core) else { return nil }
        return core + String(checkDigit)
    }

    /// ISBN-13 -> ISBN-10, only meaningful for the 978 Bookland prefix.
    static func isbn13ToISBN10(_ isbn13: String) -> String? {
        guard isbn13.count == 13, isbn13.hasPrefix("978") else { return nil }
        let core = String(isbn13.dropFirst(3).prefix(9))
        var sum = 0
        for (index, char) in core.enumerated() {
            guard let digit = char.wholeNumberValue else { return nil }
            sum += digit * (10 - index)
        }
        let remainder = sum % 11
        let checkValue = (11 - remainder) % 11
        let checkChar = checkValue == 10 ? "X" : String(checkValue)
        return core + checkChar
    }

    private static func isbn13CheckDigit(for first12: String) -> Int? {
        guard first12.count == 12 else { return nil }
        let digits = first12.compactMap { $0.wholeNumberValue }
        guard digits.count == 12 else { return nil }
        let sum = digits.enumerated().reduce(0) { partial, pair in
            let (index, digit) = pair
            return partial + digit * (index % 2 == 0 ? 1 : 3)
        }
        let remainder = sum % 10
        return remainder == 0 ? 0 : 10 - remainder
    }

    /// True if a raw EAN-13 payload looks like a Bookland (ISBN) barcode
    /// rather than an arbitrary product EAN-13.
    static func isBooklandEAN13(_ value: String) -> Bool {
        value.count == 13 && (value.hasPrefix("978") || value.hasPrefix("979"))
    }
}
