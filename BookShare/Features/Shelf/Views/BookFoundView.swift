//
//  BookFoundView.swift
//  BookShare
//
//  Brief success confirmation — checkmark + cover thumbnail — shown for a beat
//  before the flow advances into AddBookView. A transition moment, not a screen
//  the user lingers on. Reskinned to the BookShare design system.
//

import SwiftUI

struct BookFoundView: View {
    let metadata: BookMetadata
    var onFinished: () -> Void

    @State private var badgeScale: CGFloat = 0.4
    @State private var badgeOpacity: Double = 0

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()

            VStack(spacing: BSSpace.l) {
                ZStack(alignment: .topTrailing) {
                    BookCover(color: Color(hex: BookDraft.placeholderHex(for: metadata.title)),
                              title: metadata.title,
                              coverURL: metadata.highResCoverURL ?? metadata.thumbnailURL,
                              width: 104, height: 150)

                    Circle()
                        .fill(BSColor.sage)
                        .frame(width: 34, height: 34)
                        .overlay(Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(.white))
                        .overlay(Circle().strokeBorder(BSColor.card, lineWidth: 3))
                        .scaleEffect(badgeScale)
                        .opacity(badgeOpacity)
                        .offset(x: 12, y: -12)
                }

                VStack(spacing: 4) {
                    Text(metadata.title)
                        .font(BSFont.serif(19, .bold))
                        .foregroundStyle(BSColor.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    if let author = metadata.authors.first {
                        Text(author).font(BSFont.sans(13.5)).foregroundStyle(BSColor.rust)
                    }
                }
                .padding(.horizontal, BSSpace.xl)
            }
            .padding(BSSpace.xl)
            .background(BSColor.card)
            .clipShape(RoundedRectangle(cornerRadius: BSRadius.m + 4))
            .overlay(RoundedRectangle(cornerRadius: BSRadius.m + 4).strokeBorder(BSColor.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
            .padding(BSSpace.xl)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Book found: \(metadata.title)")
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                badgeScale = 1; badgeOpacity = 1
            }
            Haptics.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: onFinished)
        }
    }
}
