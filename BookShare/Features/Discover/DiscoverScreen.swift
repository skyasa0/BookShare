//
//  DiscoverScreen.swift
//  BookShare
//
//  The proximity feed. Loads neighbors' books near the signed-in user's saved
//  home via the books_near_me RPC (PostGIS radius, server-side). Falls back to
//  sample data in offline preview mode.
//

import SwiftUI

struct DiscoverScreen: View {
    @State private var genre: Book.Genre = .all
    @State private var books: [Book] = []
    @State private var phase: Phase = .loading

    private let repo = BooksRepository()

    enum Phase: Equatable { case loading, loaded, failed(String) }

    private var filtered: [Book] {
        genre == .all ? books : books.filter { $0.genre == genre }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                BSChipRow(items: Book.Genre.allCases, title: { $0.rawValue }, selection: $genre)
                    .padding(.bottom, BSSpace.m)
                content
            }
            .background(BSColor.paper)
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book, onRequested: { Task { await load() } })
            }
        }
        .tint(BSColor.rust)
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: BSSpace.xs) {
            HStack {
                Text("Discover").font(BSFont.title).foregroundStyle(BSColor.ink)
                Spacer()
                Image(systemName: "map").font(.system(size: 18, weight: .medium))
                    .foregroundStyle(BSColor.rust).frame(width: 44, height: 44)
            }
            HStack(spacing: 4) {
                Image(systemName: "scope").font(.system(size: 11))
                Text("Books within 2 mi of you")
            }
            .font(BSFont.mono(12)).foregroundStyle(BSColor.muted)
        }
        .padding(.horizontal, BSSpace.xl)
        .padding(.top, BSSpace.s)
        .padding(.bottom, BSSpace.m)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            Spacer(); ProgressView().tint(BSColor.rust); Spacer()
        case .failed(let message):
            EmptyState(icon: "wifi.exclamationmark", title: "Couldn't load nearby books",
                       message: message, retry: { Task { await load() } })
        case .loaded where filtered.isEmpty:
            EmptyState(icon: "books.vertical", title: "No books nearby yet",
                       message: "Be the first to list a book on your block — neighbors will see it here.",
                       retry: nil)
        case .loaded:
            ScrollView {
                LazyVStack(spacing: BSSpace.m) {
                    ForEach(filtered) { book in
                        NavigationLink(value: book) { BSBookCard(book: book) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, BSSpace.xl)
                .padding(.bottom, BSSpace.xl)
            }
            .refreshable { await load() }
        }
    }

    private func load() async {
        if AppLaunch.offlinePreview {
            books = SampleData.discover; phase = .loaded; return
        }
        phase = books.isEmpty ? .loading : phase
        do {
            books = try await repo.nearMe()
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

private struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    let retry: (() -> Void)?

    var body: some View {
        VStack(spacing: BSSpace.m) {
            Spacer()
            Image(systemName: icon).font(.system(size: 34)).foregroundStyle(BSColor.muted)
            Text(title).font(BSFont.serif(19, .bold)).foregroundStyle(BSColor.ink)
            Text(message).font(BSFont.body).foregroundStyle(BSColor.muted)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            if let retry {
                BSButton(title: "Try again", style: .ghost, fullWidth: false, action: retry)
                    .padding(.top, BSSpace.xs)
            }
            Spacer()
        }
        .padding(.horizontal, BSSpace.xl)
        .frame(maxWidth: .infinity)
    }
}

#Preview { DiscoverScreen() }
