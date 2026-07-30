//
//  HapticsAndImageExtensions.swift
//  BookShare
//

import SwiftUI
import UIKit

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// Light tick used while a barcode is being tracked but hasn't stabilized yet.
    static func selectionTick() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

/// A SwiftUI Image view backed by `ImageCache`, with a placeholder while
/// loading. Used anywhere a remote cover URL needs to render — the scanner's
/// "Book Found" card, AddBookView, Shelf, Discover.
struct CachedAsyncImage: View {
    let url: URL?
    var contentMode: ContentMode = .fit

    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                    if isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "book.closed")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        guard let url else {
            isLoading = false
            return
        }
        isLoading = true
        image = await ImageCache.shared.image(for: url)
        isLoading = false
    }
}
