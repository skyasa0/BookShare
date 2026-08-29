//
//  BookDetailView.swift
//  BookShare
//
//  A neighbor's book: the details plus the "Request to borrow" action that
//  kicks off the loan lifecycle. Pushed from a Discover card.
//

import SwiftUI

struct BookDetailView: View {
    let book: Book
    /// Called after a successful request so Discover can refresh.
    var onRequested: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var requested = false
    @State private var error: String?

    private let repo = LoansRepository()

    var body: some View {
        ScrollView {
            VStack(spacing: BSSpace.l) {
                BookCover(color: book.coverColor, title: book.title,
                          coverURL: book.coverURL, width: 150, height: 214)
                    .padding(.top, BSSpace.l)

                VStack(spacing: BSSpace.xs) {
                    Text(book.title)
                        .font(BSFont.serif(24, .bold))
                        .foregroundStyle(BSColor.ink)
                        .multilineTextAlignment(.center)
                    Text(book.author)
                        .font(BSFont.sans(15))
                        .foregroundStyle(BSColor.rust)
                }
                .padding(.horizontal, BSSpace.xl)

                // Owner + trust row
                HStack(spacing: BSSpace.s) {
                    if book.ownerVerified { BSVerifiedBadge(rating: book.rating) }
                    BSStatusBadge(status: book.status)
                }

                // Meta grid
                HStack(spacing: BSSpace.m) {
                    MetaTile(icon: "scope", label: "Distance", value: book.distanceLabel)
                    MetaTile(icon: "books.vertical", label: "Genre", value: book.genre.rawValue)
                    MetaTile(icon: "person", label: "Owner", value: book.ownerName)
                }
                .padding(.horizontal, BSSpace.xl)

                if let error { InlineBanner(text: error, tone: .attention).padding(.horizontal, BSSpace.xl) }
                if requested {
                    InlineBanner(text: "Request sent! You'll see it on Home. We'll let \(book.ownerName) know.",
                                 tone: .positive).padding(.horizontal, BSSpace.xl)
                }

                Spacer(minLength: BSSpace.l)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if book.status == .available && !requested {
                    BSButton(title: "Request to borrow", icon: "hand.raised.fill", isLoading: busy) {
                        request()
                    }
                    .padding(BSSpace.xl)
                } else if requested {
                    BSButton(title: "Requested", style: .ghost) { dismiss() }
                        .disabled(true).padding(BSSpace.xl)
                } else {
                    BSButton(title: "On loan right now", style: .ghost) {}
                        .disabled(true).padding(BSSpace.xl)
                }
            }
            .background(BSColor.paper)
        }
        .background(BSColor.paper)
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }

    private func request() {
        busy = true; error = nil
        Task {
            do {
                try await repo.requestLoan(bookID: book.id)
                requested = true
                onRequested()
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }
}

private struct MetaTile: View {
    let icon: String
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(BSColor.rust)
            Text(value).font(BSFont.sans(13, .semibold)).foregroundStyle(BSColor.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(BSFont.sans(10.5)).foregroundStyle(BSColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BSSpace.m)
        .background(BSColor.card)
        .clipShape(RoundedRectangle(cornerRadius: BSRadius.m))
        .overlay(RoundedRectangle(cornerRadius: BSRadius.m).strokeBorder(BSColor.line, lineWidth: 1))
    }
}
