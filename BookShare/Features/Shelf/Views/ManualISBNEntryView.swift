//
//  ManualISBNEntryView.swift
//  BookShare
//
//  Fallback entry point when the camera is unavailable, denied, or the user
//  simply prefers typing. Validates live against ISBNValidator and feeds the
//  exact same capture path as a camera scan. Reskinned to the BookShare
//  design system.
//

import SwiftUI

struct ManualISBNEntryView: View {
    var onSubmit: (String) -> Void

    @State private var rawText = ""
    @Environment(\.dismiss) private var dismiss

    private var isValid: Bool { ISBN(raw: rawText) != nil }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: BSSpace.l) {
                Text("Enter ISBN")
                    .font(BSFont.display)
                    .foregroundStyle(BSColor.ink)
                    .padding(.top, BSSpace.s)

                Text("Found on the back cover or copyright page, usually just below the barcode.")
                    .font(BSFont.body)
                    .foregroundStyle(BSColor.muted)
                    .fixedSize(horizontal: false, vertical: true)

                BSField(label: "ISBN", placeholder: "978 0 13 468599 1",
                        text: $rawText, keyboard: .numbersAndPunctuation)

                if !rawText.isEmpty {
                    InlineBanner(
                        text: isValid ? "Valid ISBN — ready to look up."
                                      : "Checksum doesn't match. Double-check the digits.",
                        tone: isValid ? .positive : .attention
                    )
                }

                Spacer()

                BSButton(title: "Find book") {
                    onSubmit(rawText)
                    dismiss()
                }
                .disabled(!isValid)
            }
            .padding(.horizontal, BSSpace.xl)
            .padding(.bottom, BSSpace.xl)
            .bsScreen()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(BSColor.rust)
                }
            }
        }
        .tint(BSColor.rust)
    }
}

#Preview { ManualISBNEntryView(onSubmit: { _ in }) }
