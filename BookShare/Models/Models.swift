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
    let id: UUID
    let title: String
    let author: String
    let genre: Genre
    let coverHex: String        // fallback color when no cover art
    let coverURL: URL?          // real cover art (from ISBN metadata), when available
    let distanceMiles: Double   // rounded distance, never raw coordinates
    let ownerName: String
    let ownerVerified: Bool
    let rating: Double
    var status: LoanStatus

    init(id: UUID = UUID(), title: String, author: String, genre: Genre,
         coverHex: String, coverURL: URL? = nil, distanceMiles: Double, ownerName: String,
         ownerVerified: Bool, rating: Double, status: LoanStatus) {
        self.id = id; self.title = title; self.author = author; self.genre = genre
        self.coverHex = coverHex; self.coverURL = coverURL; self.distanceMiles = distanceMiles
        self.ownerName = ownerName; self.ownerVerified = ownerVerified
        self.rating = rating; self.status = status
    }

    enum Genre: String, CaseIterable, Identifiable {
        case all = "All", fiction = "Fiction", nonfiction = "Nonfiction", kids = "Kids"
        var id: String { rawValue }

        /// Map from the Postgres `book_genre` enum values.
        init?(dbValue: String) {
            switch dbValue {
            case "fiction":    self = .fiction
            case "nonfiction": self = .nonfiction
            case "kids":       self = .kids
            default:           return nil
            }
        }

        /// Postgres `book_genre` value (nil for `.all`, which isn't a stored genre).
        var dbValue: String? {
            switch self {
            case .fiction:    return "fiction"
            case .nonfiction: return "nonfiction"
            case .kids:       return "kids"
            case .all:        return nil
            }
        }
    }

    var coverColor: Color { Color(hex: coverHex) }
    var distanceLabel: String { String(format: "%.1f mi", distanceMiles) }
}

struct Loan: Identifiable {
    let id: UUID
    let book: Book
    var status: LoanStatus
    let counterparty: String       // the other neighbor on this loan
    let counterpartyPhone: String? // revealed only once accepted (for WhatsApp)
    let dueDate: Date?
    let isLender: Bool             // true = you're lending, false = you're borrowing
    // Handoff coordination (accepted stage)
    let handoffPlace: String?
    let handoffTime: Date?
    let handoffProposedByMe: Bool

    init(id: UUID = UUID(), book: Book, status: LoanStatus, counterparty: String,
         counterpartyPhone: String? = nil, dueDate: Date? = nil, isLender: Bool,
         handoffPlace: String? = nil, handoffTime: Date? = nil, handoffProposedByMe: Bool = false) {
        self.id = id; self.book = book; self.status = status
        self.counterparty = counterparty; self.counterpartyPhone = counterpartyPhone
        self.dueDate = dueDate; self.isLender = isLender
        self.handoffPlace = handoffPlace; self.handoffTime = handoffTime
        self.handoffProposedByMe = handoffProposedByMe
    }

    /// Whether a handoff spot/time has been proposed.
    var hasHandoffProposal: Bool { handoffPlace != nil }

    var dueLabel: String? {
        guard let dueDate else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "Due \(f.string(from: dueDate))"
    }

    var handoffLabel: String? {
        guard let place = handoffPlace else { return nil }
        guard let time = handoffTime else { return place }
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d, h:mm a"
        return "\(place) · \(f.string(from: time))"
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
