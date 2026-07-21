//
//  DiscoverScreen.swift
//  BookShare
//
//  The proximity feed: filter by genre, browse neighbors' shelves nearby.
//  Radius query would run server-side (PostGIS); here it's sample data.
//

import SwiftUI

struct DiscoverScreen: View {
    @State private var genre: Book.Genre = .all
    private let books = SampleData.discover

    private var filtered: [Book] {
        genre == .all ? books : books.filter { $0.genre == genre }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: BSSpace.xs) {
                HStack {
                    Text("Discover")
                        .font(BSFont.title)
                        .foregroundStyle(BSColor.ink)
                    Spacer()
                    Image(systemName: "map")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(BSColor.rust)
                        .frame(width: 44, height: 44)
                }
                HStack(spacing: 4) {
                    Image(systemName: "scope").font(.system(size: 11))
                    Text("Within 2 mi of \(SampleData.me.neighborhood)")
                }
                .font(BSFont.mono(12))
                .foregroundStyle(BSColor.muted)
            }
            .padding(.horizontal, BSSpace.xl)
            .padding(.top, BSSpace.s)
            .padding(.bottom, BSSpace.m)

            BSChipRow(items: Book.Genre.allCases, title: { $0.rawValue }, selection: $genre)
                .padding(.bottom, BSSpace.m)

            ScrollView {
                LazyVStack(spacing: BSSpace.m) {
                    ForEach(filtered) { book in
                        BSBookCard(book: book)
                    }
                }
                .padding(.horizontal, BSSpace.xl)
                .padding(.bottom, BSSpace.xl)
            }
        }
        .background(BSColor.paper)
    }
}

#Preview { DiscoverScreen() }
