//
//  LoadingView.swift
//  BookShare
//
//  Shown between a stable barcode capture and the metadata fetch resolving.
//  Reskinned to the BookShare design system; floats as a paper card over
//  whatever is behind (live camera on device, fallback screen on simulator).
//

import SwiftUI

struct LoadingView: View {
    var isbn: ISBN

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()

            VStack(spacing: BSSpace.l) {
                ProgressView().controlSize(.large).tint(BSColor.rust)
                VStack(spacing: 4) {
                    Text("Finding book…")
                        .font(BSFont.serif(20, .bold))
                        .foregroundStyle(BSColor.ink)
                    Text(isbn.displayFormatted)
                        .font(BSFont.mono(12))
                        .foregroundStyle(BSColor.muted)
                }
            }
            .padding(28)
            .background(BSColor.card)
            .clipShape(RoundedRectangle(cornerRadius: BSRadius.m + 4))
            .overlay(RoundedRectangle(cornerRadius: BSRadius.m + 4).strokeBorder(BSColor.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Finding book, please wait")
    }
}

#Preview { LoadingView(isbn: ISBN(raw: "9780134685991")!) }
