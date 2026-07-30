//
//  ShelfScreen.swift
//  BookShare
//
//  Your shelf — the books you've listed for neighbors. Add a book via ISBN
//  scan (BR-01) or by title.
//

import SwiftUI

struct ShelfScreen: View {
    @State private var books: [Book] = []
    @State private var loaded = false
    @State private var showScanner = false

    private let repo = BooksRepository()

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
                    Button { showScanner = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(BSColor.onRust)
                            .frame(width: 40, height: 40)
                            .background(BSColor.rust)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Add a book")
                }
                .padding(.top, BSSpace.s)

                HStack(spacing: BSSpace.m) {
                    StatTile(value: "\(books.count)", label: "Listed")
                    StatTile(value: "\(available)", label: "Available")
                    StatTile(value: "\(onLoan)", label: "On loan")
                }

                BSButton(title: "Scan a book's barcode", icon: "barcode.viewfinder",
                         style: .ghost) { showScanner = true }

                Text("Listed books")
                    .font(BSFont.serif(18, .bold))
                    .foregroundStyle(BSColor.ink)
                    .padding(.top, BSSpace.xs)

                if books.isEmpty && loaded {
                    ShelfEmptyState()
                } else {
                    ForEach(books) { book in
                        BSBookCard(book: book, showLocation: false)
                    }
                }
            }
            .padding(.horizontal, BSSpace.xl)
            .padding(.bottom, BSSpace.xl)
        }
        .background(BSColor.paper)
        .task { await load() }
        .refreshable { await load() }
        .onAppear { if AppLaunch.scanDemo { showScanner = true } }
        .fullScreenCover(isPresented: $showScanner) {
            ScannerView {
                // Published a book: close the scanner and refresh the shelf.
                showScanner = false
                Task { await load() }
            }
        }
    }

    private func load() async {
        if AppLaunch.offlinePreview {
            books = SampleData.shelf; loaded = true; return
        }
        books = (try? await repo.myShelf()) ?? []
        loaded = true
    }
}

private struct ShelfEmptyState: View {
    var body: some View {
        VStack(spacing: BSSpace.s) {
            Image(systemName: "books.vertical").font(.system(size: 30)).foregroundStyle(BSColor.muted)
            Text("Your shelf is empty")
                .font(BSFont.serif(17, .bold)).foregroundStyle(BSColor.ink)
            Text("List a book you're happy to lend and neighbors nearby will find it on Discover.")
                .font(BSFont.body).foregroundStyle(BSColor.muted)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BSSpace.xl)
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
