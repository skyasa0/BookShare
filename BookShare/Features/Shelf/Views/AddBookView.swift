//
//  AddBookView.swift
//  BookShare
//
//  Final stop in the ISBN pipeline: what the scanner + metadata lookup gathered
//  lands here as editable fields, then publishes to the user's shelf. Reskinned
//  to the BookShare design system and simplified to the borrow-only, no-payments
//  product — cover, title, author, genre, condition, description.
//

import SwiftUI

struct AddBookView: View {
    let draft: BookDraft
    /// Called after the book is successfully listed, so the presenter can
    /// dismiss the whole scanner flow and refresh the shelf.
    var onPublished: () -> Void

    @State private var title: String
    @State private var authorsText: String
    @State private var genre: Book.Genre
    @State private var condition: BookCondition
    @State private var description: String
    @State private var busy = false
    @State private var error: String?

    private let repo = BooksRepository()

    init(draft: BookDraft, onPublished: @escaping () -> Void) {
        self.draft = draft
        self.onPublished = onPublished
        _title = State(initialValue: draft.title)
        _authorsText = State(initialValue: draft.authors.joined(separator: ", "))
        _genre = State(initialValue: Self.guessGenre(from: draft.genre))
        _condition = State(initialValue: draft.condition)
        _description = State(initialValue: draft.description)
    }

    private let genres: [Book.Genre] = [.fiction, .nonfiction, .kids]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BSSpace.l) {
                // Cover + title/author
                HStack(alignment: .top, spacing: BSSpace.m) {
                    BookCover(color: Color(hex: BookDraft.placeholderHex(for: draft.title)),
                              title: draft.title,
                              coverURL: draft.highResCoverURL ?? draft.thumbnailURL,
                              width: 84, height: 118)
                    VStack(alignment: .leading, spacing: BSSpace.s) {
                        BSField(label: "Title", placeholder: "Book title", text: $title)
                        Text(draft.isbn.displayFormatted)
                            .font(BSFont.mono(11.5)).foregroundStyle(BSColor.muted)
                    }
                }

                BSField(label: "Author(s)", placeholder: "Comma separated", text: $authorsText)

                field(label: "Genre") {
                    HStack(spacing: BSSpace.s) {
                        ForEach(genres) { g in
                            BSChip(title: g.rawValue, isOn: g == genre) {
                                withAnimation(.easeOut(duration: 0.15)) { genre = g }
                            }
                        }
                    }
                }

                field(label: "Condition") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: BSSpace.s) {
                            ForEach(BookCondition.allCases) { c in
                                BSChip(title: c.displayName, isOn: c == condition) {
                                    withAnimation(.easeOut(duration: 0.15)) { condition = c }
                                }
                            }
                        }
                    }
                }

                field(label: "Description") {
                    TextEditor(text: $description)
                        .font(BSFont.sans(14.5))
                        .foregroundStyle(BSColor.ink)
                        .frame(minHeight: 96)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(BSColor.field)
                        .clipShape(RoundedRectangle(cornerRadius: BSRadius.m))
                        .overlay(RoundedRectangle(cornerRadius: BSRadius.m)
                            .strokeBorder(BSColor.fieldLine, lineWidth: 1))
                }

                if let error { InlineBanner(text: error, tone: .attention) }

                BSButton(title: "List on my shelf", isLoading: busy) { publish() }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)

                PrivacyNote("Listing a book shares its title and cover with neighbors nearby — never your address.")
            }
            .padding(.horizontal, BSSpace.xl)
            .padding(.vertical, BSSpace.l)
        }
        .bsScreen()
        .navigationTitle("Add book")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: BSSpace.s) {
            Text(label).bsFieldLabel()
            content()
        }
    }

    private func publish() {
        busy = true; error = nil
        var d = draft
        d.title = title
        d.authors = authorsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        d.description = description
        Task {
            do {
                try await repo.addBook(d, genre: genre, condition: condition)
                Haptics.success()
                onPublished()
            } catch {
                self.error = error.localizedDescription
                busy = false
            }
        }
    }

    /// Best-effort map from a free-text metadata category to our 3 genres.
    private static func guessGenre(from category: String?) -> Book.Genre {
        let c = (category ?? "").lowercased()
        if c.contains("juvenile") || c.contains("children") || c.contains("kids") { return .kids }
        if c.contains("fiction") && !c.contains("non") { return .fiction }
        if c.isEmpty { return .nonfiction }
        return .nonfiction
    }
}

#Preview {
    NavigationStack {
        AddBookView(draft: BookDraft(isbn: ISBN(raw: "9780134685991")!,
                                     title: "The Swift Programming Language",
                                     authors: ["Apple Inc."]), onPublished: {})
    }
}
