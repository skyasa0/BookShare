//
//  BookMetadataViewModel.swift
//  BookShare
//
//  Takes a captured ISBN and drives the "Finding Book..." -> found/error
//  states shown after the scanner hands off. Cancels the previous fetch
//  outright if a new ISBN comes in before the old one resolves.
//

import Foundation

@MainActor
@Observable
final class BookMetadataViewModel {

    enum FetchState: Equatable {
        case idle
        case loading(ISBN)
        case found(BookMetadata)
        case notFound(ISBN)
        case offline(ISBN)
    }

    private(set) var fetchState: FetchState = .idle

    private let metadataService: BookMetadataService
    private var currentTask: Task<Void, Never>?

    init(metadataService: BookMetadataService = BookMetadataService()) {
        self.metadataService = metadataService
    }

    func fetch(isbn: ISBN) {
        currentTask?.cancel()

        fetchState = .loading(isbn)
        currentTask = Task { [metadataService] in
            do {
                let metadata = try await metadataService.fetchBook(isbn: isbn)
                guard !Task.isCancelled else { return }
                self.fetchState = .found(metadata)
            } catch {
                guard !Task.isCancelled else { return }
                if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
                    self.fetchState = .offline(isbn)
                } else if case BookMetadataError.notFound = error {
                    self.fetchState = .notFound(isbn)
                } else {
                    // Every provider failed for a reason other than a clean
                    // 404 — treat conservatively as "not found" so the user
                    // always has the manual-entry escape hatch.
                    self.fetchState = .notFound(isbn)
                }
            }
        }
    }

    /// Cancels the fetch and cancels the underlying service's in-flight
    /// network task too, per "cancel previous requests if new scan occurs."
    func cancelCurrentFetch(isbn: ISBN) {
        currentTask?.cancel()
        Task { await metadataService.cancel(isbn: isbn) }
    }

    func reset() {
        currentTask?.cancel()
        fetchState = .idle
    }
}
