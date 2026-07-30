//
//  BooksRepository.swift
//  BookShare
//
//  Reads the proximity feed (via the books_within_radius RPC) and the signed-in
//  user's own shelf. Maps DB rows to the UI `Book` model.
//

import Foundation
import Supabase

struct BooksRepository {
    private let client = SupabaseManager.client

    /// The Discover feed: neighbors' books near the signed-in user's saved home,
    /// nearest first, excluding the user's own listings. No coordinates sent —
    /// the origin is the caller's stored home_location. Distances are pre-rounded.
    func nearMe(radiusMeters: Double = 3200) async throws -> [Book] {
        let rows: [RadiusBookDTO] = try await client
            .rpc("books_near_me", params: ["radius_m": radiusMeters])
            .execute()
            .value
        return rows.map(\.asBook)
    }

    /// Books within `radiusMeters` of an explicit point, nearest first.
    /// Distances are already rounded server-side; raw coordinates never leave the DB.
    func nearby(lat: Double, lng: Double, radiusMeters: Double = 3200) async throws -> [Book] {
        let rows: [RadiusBookDTO] = try await client
            .rpc("books_within_radius", params: ["lat": lat, "lng": lng, "radius_m": radiusMeters])
            .execute()
            .value
        return rows.map(\.asBook)
    }

    /// The signed-in user's own listings. The `books` read policy allows browsing
    /// everyone's listings (for Discover), so we must filter to the current user
    /// explicitly here.
    func myShelf() async throws -> [Book] {
        guard let uid = client.auth.currentUser?.id else { return [] }
        let rows: [ShelfBookDTO] = try await client
            .from("books")
            .select("id,title,author,genre,cover_hex,cover_url,status,rating")
            .eq("owner_id", value: uid)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.map(\.asBook)
    }

    /// Lists a scanned/entered book on the signed-in user's shelf. Maps the
    /// editable `BookDraft` to the `books` row; owner defaults via RLS/`auth.uid`.
    @discardableResult
    func addBook(_ draft: BookDraft, genre: Book.Genre, condition: BookCondition) async throws -> Void {
        guard let uid = client.auth.currentUser?.id else {
            throw NSError(domain: "BookShare", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "You need to be signed in to list a book."])
        }
        let row = NewBookRow(
            owner_id: uid.uuidString,
            title: draft.title,
            author: draft.authors.joined(separator: ", "),
            genre: genre.dbValue ?? "fiction",
            cover_hex: BookDraft.placeholderHex(for: draft.title),
            cover_url: draft.highResCoverURL?.absoluteString ?? draft.thumbnailURL?.absoluteString,
            description: draft.description.isEmpty ? nil : draft.description,
            condition: condition.dbValue,
            isbn: draft.isbn.isbn13,
            status: "available"
        )
        try await client.from("books").insert(row).execute()
    }
}

/// Encodable payload for inserting a new listing.
private struct NewBookRow: Encodable {
    let owner_id: String
    let title: String
    let author: String
    let genre: String
    let cover_hex: String
    let cover_url: String?
    let description: String?
    let condition: String
    let isbn: String
    let status: String
}

// MARK: - DTOs

/// Row shape of `books_within_radius`.
private struct RadiusBookDTO: Decodable {
    let id: UUID
    let title: String
    let author: String
    let genre: String
    let cover_hex: String
    let cover_url: String?
    let status: String
    let rating: Double
    let owner_name: String
    let owner_verified: Bool
    let distance_mi: Double

    var asBook: Book {
        Book(id: id, title: title, author: author,
             genre: Book.Genre(dbValue: genre) ?? .fiction,
             coverHex: cover_hex, coverURL: cover_url.flatMap(URL.init(string:)),
             distanceMiles: distance_mi,
             ownerName: owner_name, ownerVerified: owner_verified,
             rating: rating, status: LoanStatus(dbValue: status) ?? .available)
    }
}

/// Row shape of a `books` table select (own shelf — no distance/owner columns).
private struct ShelfBookDTO: Decodable {
    let id: UUID
    let title: String
    let author: String
    let genre: String
    let cover_hex: String
    let cover_url: String?
    let status: String
    let rating: Double

    var asBook: Book {
        Book(id: id, title: title, author: author,
             genre: Book.Genre(dbValue: genre) ?? .fiction,
             coverHex: cover_hex, coverURL: cover_url.flatMap(URL.init(string:)),
             distanceMiles: 0,
             ownerName: "You", ownerVerified: true,
             rating: rating, status: LoanStatus(dbValue: status) ?? .available)
    }
}
