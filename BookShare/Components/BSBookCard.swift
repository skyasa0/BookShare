//
//  BSBookCard.swift
//  BookShare
//
//  The workhorse. Fixed anatomy: cover, serif title, terracotta author,
//  mono distance + owner, badge, gilt rating. Nothing is optional — trust
//  needs all six signals present. (Deliverable 14 §04)
//

import SwiftUI

struct BSBookCard: View {
    let book: Book
    /// Shows distance + owner on Discover; hidden on your own Shelf.
    var showLocation: Bool = true

    var body: some View {
        HStack(spacing: BSSpace.m) {
            BookCover(color: book.coverColor, title: book.title, coverURL: book.coverURL)

            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(BSFont.cardTitle)
                    .foregroundStyle(BSColor.ink)
                    .lineLimit(2)
                Text(book.author)
                    .font(BSFont.sans(12.5))
                    .foregroundStyle(BSColor.rust)
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    if showLocation {
                        Image(systemName: "scope").font(.system(size: 10))
                        Text("\(book.distanceLabel) · \(book.ownerName)")
                    } else {
                        Text(book.genre.rawValue)
                    }
                }
                .font(BSFont.mono(11.5))
                .foregroundStyle(BSColor.muted)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: BSSpace.s) {
                BSStatusBadge(status: book.status)
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").foregroundStyle(BSColor.gold)
                    Text(String(format: "%.1f", book.rating)).foregroundStyle(BSColor.ink)
                }
                .font(BSFont.sans(12, .semibold))
            }
        }
        .padding(BSSpace.m)
        .frame(minHeight: 96)
        .background(BSColor.card)
        .clipShape(RoundedRectangle(cornerRadius: BSRadius.m + 1))
        .overlay(
            RoundedRectangle(cornerRadius: BSRadius.m + 1)
                .strokeBorder(BSColor.line, lineWidth: 1)
        )
    }
}

/// Book cover stand-in with a subtle spine + embossed initials. In production
/// this is replaced with cached Open Library art (alt text from metadata).
struct BookCover: View {
    let color: Color
    let title: String
    /// Real cover art (from ISBN metadata). When nil, the colored spine placeholder shows.
    var coverURL: URL? = nil
    var width: CGFloat = 56
    var height: CGFloat = 74

    var body: some View {
        Group {
            if let coverURL {
                CachedAsyncImage(url: coverURL, contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .background(color)
            } else {
                placeholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: BSRadius.s))
        .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
        .accessibilityLabel("Cover of \(title)")
    }

    private var placeholder: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: BSRadius.s)
                .fill(color)
            Rectangle()
                .fill(.white.opacity(0.18))
                .frame(width: 4)
                .padding(.leading, 6)
            Text(title.prefix(1))
                .font(BSFont.serif(20, .bold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        BSBookCard(book: SampleData.discover[0])
        BSBookCard(book: SampleData.discover[3])
        BSBookCard(book: SampleData.shelf[0], showLocation: false)
    }
    .padding(BSSpace.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BSColor.paper)
}
