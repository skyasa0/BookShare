//
//  SampleData.swift
//  BookShare
//
//  Seed content so every screen renders like a real neighborhood shelf.
//  Voice rule (§07): books, neighbors, shelves, loans — never items/users.
//

import Foundation

enum SampleData {

    static let me = UserProfile(
        name: "Jane Smith",
        neighborhood: "Cobble Hill",
        avatarHex: "A8431F",
        verified: true,
        rating: 4.9,
        loansGiven: 12,
        loansTaken: 8
    )

    // Discover feed — a mix of genres, distances, owners, and statuses.
    static let discover: [Book] = [
        Book(title: "Quiet Machines", author: "H. Roper", genre: .fiction,
             coverHex: "8E6F4E", distanceMiles: 0.9, ownerName: "Jin W.",
             ownerVerified: true, rating: 4.8, status: .available),
        Book(title: "Book of Ordinary Anguish", author: "M. Delacroix", genre: .fiction,
             coverHex: "6B4A3A", distanceMiles: 0.3, ownerName: "Alma R.",
             ownerVerified: true, rating: 5.0, status: .available),
        Book(title: "The Salt Path", author: "R. Winn", genre: .nonfiction,
             coverHex: "4F6353", distanceMiles: 1.2, ownerName: "Priya K.",
             ownerVerified: false, rating: 4.6, status: .available),
        Book(title: "Tiny Habits", author: "BJ Fogg", genre: .nonfiction,
             coverHex: "9A7B3F", distanceMiles: 0.5, ownerName: "Marcus T.",
             ownerVerified: true, rating: 4.7, status: .onLoan),
        Book(title: "Where the Crawdads Sing", author: "D. Owens", genre: .fiction,
             coverHex: "3E5266", distanceMiles: 0.7, ownerName: "Sofia L.",
             ownerVerified: true, rating: 4.9, status: .available),
        Book(title: "The Gruffalo", author: "J. Donaldson", genre: .kids,
             coverHex: "7C5A9B", distanceMiles: 0.4, ownerName: "Dev P.",
             ownerVerified: true, rating: 4.8, status: .available),
        Book(title: "Braiding Sweetgrass", author: "R. Kimmerer", genre: .nonfiction,
             coverHex: "556B3F", distanceMiles: 1.6, ownerName: "Nadia H.",
             ownerVerified: true, rating: 5.0, status: .available),
        Book(title: "The Very Hungry Caterpillar", author: "E. Carle", genre: .kids,
             coverHex: "B4632A", distanceMiles: 0.8, ownerName: "Omar F.",
             ownerVerified: false, rating: 4.5, status: .available),
    ]

    // Your Home queue — active loans in flight.
    static var homeQueue: [Loan] {
        [
            Loan(book: discover[1], status: .accepted, counterparty: "Alma R.",
                 dueDate: nil, isLender: false),
            Loan(book: discover[0], status: .requested, counterparty: "Jin W.",
                 dueDate: nil, isLender: false),
            Loan(book: shelf[0], status: .onLoan, counterparty: "Marcus T.",
                 dueDate: Calendar.current.date(byAdding: .day, value: 9, to: Date()),
                 isLender: true),
        ]
    }

    // Your Shelf — books you've listed for neighbors.
    static let shelf: [Book] = [
        Book(title: "Klara and the Sun", author: "K. Ishiguro", genre: .fiction,
             coverHex: "C9973C", distanceMiles: 0, ownerName: "You",
             ownerVerified: true, rating: 4.9, status: .onLoan),
        Book(title: "Circe", author: "M. Miller", genre: .fiction,
             coverHex: "8A3617", distanceMiles: 0, ownerName: "You",
             ownerVerified: true, rating: 4.9, status: .available),
        Book(title: "Atomic Habits", author: "J. Clear", genre: .nonfiction,
             coverHex: "55663F", distanceMiles: 0, ownerName: "You",
             ownerVerified: true, rating: 4.9, status: .available),
        Book(title: "Goodnight Moon", author: "M. Wise Brown", genre: .kids,
             coverHex: "3E5266", distanceMiles: 0, ownerName: "You",
             ownerVerified: true, rating: 4.9, status: .available),
    ]
}
