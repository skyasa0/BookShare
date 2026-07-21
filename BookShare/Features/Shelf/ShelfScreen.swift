//
//  ShelfScreen.swift
//  BookShare
//
//  Your shelf — the books you've listed for neighbors. Add a book via ISBN
//  scan (BR-01) or by title.
//

import SwiftUI

struct ShelfScreen: View {
    private let books = SampleData.shelf

    private var available: Int { books.filter { $0.status == .available }.count }
    private var onLoan: Int { books.filter { $0.status == .onLoan }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BSSpace.l) {
                HStack {
                    Text("Your shelf")
                        .font(BSFont.title)
                        .foregroundStyle(BSColor.ink)
                    Spacer()
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(BSColor.onRust)
                        .frame(width: 40, height: 40)
                        .background(BSColor.rust)
                        .clipShape(Circle())
                }
                .padding(.top, BSSpace.s)

                HStack(spacing: BSSpace.m) {
                    StatTile(value: "\(books.count)", label: "Listed")
                    StatTile(value: "\(available)", label: "Available")
                    StatTile(value: "\(onLoan)", label: "On loan")
                }

                BSButton(title: "Scan a book's barcode", icon: "barcode.viewfinder",
                         style: .ghost) {}

                Text("Listed books")
                    .font(BSFont.serif(18, .bold))
                    .foregroundStyle(BSColor.ink)
                    .padding(.top, BSSpace.xs)

                ForEach(books) { book in
                    BSBookCard(book: book, showLocation: false)
                }
            }
            .padding(.horizontal, BSSpace.xl)
            .padding(.bottom, BSSpace.xl)
        }
        .background(BSColor.paper)
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(BSFont.serif(22, .bold))
                .foregroundStyle(BSColor.rust)
            Text(label)
                .font(BSFont.sans(11.5, .medium))
                .foregroundStyle(BSColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BSSpace.m)
        .background(BSColor.card)
        .clipShape(RoundedRectangle(cornerRadius: BSRadius.m))
        .overlay(
            RoundedRectangle(cornerRadius: BSRadius.m).strokeBorder(BSColor.line, lineWidth: 1)
        )
    }
}

#Preview { ShelfScreen() }
