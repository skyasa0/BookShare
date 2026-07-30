//
//  BookFetchErrorView.swift
//  BookShare
//
//  Shown when a valid ISBN returned nothing from any metadata provider, or the
//  device is offline. Always offers the manual escape hatch. Reskinned to the
//  BookShare design system.
//

import SwiftUI

struct BookFetchErrorView: View {
    enum Kind {
        case notFound(ISBN)
        case offline(ISBN)
    }

    let kind: Kind
    var onRetry: () -> Void
    var onEnterManually: () -> Void
    var onAddWithoutMetadata: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()

            VStack(spacing: BSSpace.l) {
                Image(systemName: iconName)
                    .font(.system(size: 34))
                    .foregroundStyle(BSColor.muted)

                VStack(spacing: 6) {
                    Text(title).font(BSFont.serif(19, .bold)).foregroundStyle(BSColor.ink)
                    Text(message).font(BSFont.body).foregroundStyle(BSColor.muted)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: BSSpace.s) {
                    BSButton(title: "Try again", action: onRetry)
                    BSButton(title: "Add details myself", style: .ghost, action: onAddWithoutMetadata)
                }
            }
            .padding(BSSpace.xl)
            .background(BSColor.card)
            .clipShape(RoundedRectangle(cornerRadius: BSRadius.m + 4))
            .overlay(RoundedRectangle(cornerRadius: BSRadius.m + 4).strokeBorder(BSColor.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
            .padding(BSSpace.xl)
        }
    }

    private var iconName: String {
        switch kind {
        case .notFound: "book.closed"
        case .offline: "wifi.slash"
        }
    }
    private var title: String {
        switch kind {
        case .notFound: "Book not found"
        case .offline: "No connection"
        }
    }
    private var message: String {
        switch kind {
        case .notFound(let isbn):
            "We couldn't find details for \(isbn.displayFormatted) in any of our sources. You can still list it with your own details."
        case .offline:
            "We couldn't reach the book catalog. Check your connection and try again."
        }
    }
}

#Preview {
    BookFetchErrorView(kind: .notFound(ISBN(raw: "9780134685991")!),
                       onRetry: {}, onEnterManually: {}, onAddWithoutMetadata: {})
}
