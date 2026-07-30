//
//  ScannerErrorBanner.swift
//  BookShare
//
//  Compact, retry-to-dismiss card for scan-time errors (invalid ISBN, barcode
//  too small, multiple barcodes, low light) — distinct from the post-fetch
//  "not found / offline" states in BookFetchErrorView. Reskinned to BS.
//

import SwiftUI

struct ScannerErrorBanner: View {
    let reason: ScannerViewModel.ScanErrorReason
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: BSSpace.m) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2).foregroundStyle(BSColor.gold)
            VStack(spacing: 4) {
                Text(reason.title).font(BSFont.serif(18, .bold)).foregroundStyle(BSColor.ink)
                Text(reason.message).font(BSFont.sans(13)).foregroundStyle(BSColor.muted)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            BSButton(title: "Try again", fullWidth: false, action: onRetry)
        }
        .padding(BSSpace.xl)
        .frame(maxWidth: 320)
        .background(BSColor.card)
        .clipShape(RoundedRectangle(cornerRadius: BSRadius.m + 4))
        .overlay(RoundedRectangle(cornerRadius: BSRadius.m + 4).strokeBorder(BSColor.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
        .accessibilityElement(children: .combine)
    }
}

struct ScannerHelpSheet: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Getting a good scan") {
                    Label("Center the barcode inside the frame", systemImage: "viewfinder")
                    Label("Hold steady for a second — it captures automatically", systemImage: "hand.raised")
                    Label("Turn on flash in low light", systemImage: "bolt")
                    Label("Move a bit closer if the barcode looks tiny", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                Section("No barcode handy?") {
                    Label("Type the ISBN in manually", systemImage: "keyboard")
                    Label("Scan a photo from your library", systemImage: "photo")
                }
            }
            .navigationTitle("Scanning help")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(BSColor.rust)
    }
}

#Preview { ScannerErrorBanner(reason: .invalidISBN, onRetry: {}) }
