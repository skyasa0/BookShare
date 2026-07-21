//
//  Models.swift
//  BookShare
//
//  Lightweight content entities (Deliverable 07) used to drive the UI with
//  sample data. These are plain value types — not SwiftData @Model — so the
//  MVP UI can render without a backend. Supabase-backed models come later.
//

import SwiftUI

struct Book: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let author: String
    let genre: Genre
    let coverHex: String        // stand-in for Open Library cover art
    let distanceMiles: Double   // rounded distance, never raw coordinates
    let ownerName: String
    let ownerVerified: Bool
    let rating: Double
    var status: LoanStatus

    enum Genre: String, CaseIterable, Identifiable {
        case all = "All", fiction = "Fiction", nonfiction = "Nonfiction", kids = "Kids"
        var id: String { rawValue }
    }

    var coverColor: Color { Color(hex: coverHex) }
    var distanceLabel: String { String(format: "%.1f mi", distanceMiles) }
}

struct Loan: Identifiable {
    let id = UUID()
    let book: Book
    var status: LoanStatus
    let counterparty: String   // the other neighbor on this loan
    let dueDate: Date?
    let isLender: Bool         // true = you're lending, false = you're borrowing

    var dueLabel: String? {
        guard let dueDate else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "Due \(f.string(from: dueDate))"
    }
}

struct UserProfile {
    let name: String
    let neighborhood: String
    let avatarHex: String
    let verified: Bool
    let rating: Double
    let loansGiven: Int
    let loansTaken: Int

    var avatarColor: Color { Color(hex: avatarHex) }
    var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}
