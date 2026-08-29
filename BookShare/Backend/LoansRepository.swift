//
//  LoansRepository.swift
//  BookShare
//
//  The loan lifecycle client. All state transitions go through the SECURITY
//  DEFINER RPCs (request/respond/handoff/return/rate); the client never writes
//  loan rows directly.
//

import Foundation
import Supabase

struct LoansRepository {
    private let client = SupabaseManager.client

    /// The signed-in user's loans (borrowing + lending) for the Home queue.
    func myLoans() async throws -> [Loan] {
        let uid = client.auth.currentUser?.id
        let rows: [LoanDTO] = try await client.rpc("my_loans").execute().value
        return rows.map { $0.asLoan(currentUserID: uid) }
    }

    /// Request to borrow a book. Returns the new loan id.
    @discardableResult
    func requestLoan(bookID: UUID) async throws -> UUID {
        try await client.rpc("request_loan", params: ["p_book_id": bookID.uuidString])
            .execute().value
    }

    func respond(loanID: UUID, accept: Bool) async throws {
        try await client.rpc("respond_to_loan",
                             params: ["p_loan_id": AnyJSON.string(loanID.uuidString),
                                      "p_accept": AnyJSON.bool(accept)]).execute()
    }

    func proposeHandoff(loanID: UUID, place: String, time: Date) async throws {
        let iso = ISO8601DateFormatter().string(from: time)
        try await client.rpc("propose_handoff",
                             params: ["p_loan_id": loanID.uuidString,
                                      "p_place": place,
                                      "p_time": iso]).execute()
    }

    func confirmHandoff(loanID: UUID) async throws {
        try await client.rpc("confirm_handoff", params: ["p_loan_id": loanID.uuidString]).execute()
    }

    func markReturned(loanID: UUID) async throws {
        try await client.rpc("mark_returned", params: ["p_loan_id": loanID.uuidString]).execute()
    }

    func rate(loanID: UUID, stars: Int, comment: String?) async throws {
        try await client.rpc("rate_loan",
                             params: ["p_loan_id": AnyJSON.string(loanID.uuidString),
                                      "p_stars": AnyJSON.integer(stars),
                                      "p_comment": comment.map(AnyJSON.string) ?? .null]).execute()
    }
}

// MARK: - DTO

private struct LoanDTO: Decodable {
    let id: UUID
    let status: String
    let is_lender: Bool
    let book_title: String
    let book_author: String
    let book_cover_hex: String
    let book_cover_url: String?
    let counterparty_name: String
    let counterparty_phone: String?
    let handoff_place: String?
    let handoff_time: String?   // timestamptz as ISO8601 text
    let handoff_proposed_by: UUID?
    let due_date: String?       // "yyyy-MM-dd"

    private static let isoFull: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()
    private static let dayOnly: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = TimeZone(identifier: "UTC"); return f
    }()

    func asLoan(currentUserID: UUID?) -> Loan {
        let handoffDate = handoff_time.flatMap { Self.isoFull.date(from: $0) ?? Self.iso.date(from: $0) }
        let dueDate = due_date.flatMap { Self.dayOnly.date(from: $0) }
        // Minimal Book for the loan card (only title/cover are shown there).
        let book = Book(title: book_title, author: book_author, genre: .fiction,
                        coverHex: book_cover_hex,
                        coverURL: book_cover_url.flatMap(URL.init(string:)),
                        distanceMiles: 0, ownerName: counterparty_name,
                        ownerVerified: false, rating: 0,
                        status: LoanStatus(dbValue: status) ?? .requested)
        return Loan(
            id: id,
            book: book,
            status: LoanStatus(dbValue: status) ?? .requested,
            counterparty: counterparty_name,
            counterpartyPhone: counterparty_phone,
            dueDate: dueDate,
            isLender: is_lender,
            handoffPlace: handoff_place,
            handoffTime: handoffDate,
            handoffProposedByMe: handoff_proposed_by != nil && handoff_proposed_by == currentUserID
        )
    }
}
