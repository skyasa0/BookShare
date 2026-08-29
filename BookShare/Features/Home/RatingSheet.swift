//
//  RatingSheet.swift
//  BookShare
//
//  Two-sided reliability rating after a loan is returned (BR-06). Stars plus an
//  optional note; feeds the neighbor's reliability score.
//

import SwiftUI

struct RatingSheet: View {
    let loan: Loan
    /// (stars, comment?) -> perform. Called on submit; the sheet then dismisses.
    let onSubmit: (Int, String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var stars = 5
    @State private var comment = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: BSSpace.l) {
                Text("Rate \(loan.counterparty)")
                    .font(BSFont.display).foregroundStyle(BSColor.ink).padding(.top, BSSpace.s)
                Text("How did the \(loan.isLender ? "loan" : "borrow") go? Your rating builds trust for the whole block.")
                    .font(BSFont.body).foregroundStyle(BSColor.muted)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: BSSpace.s) {
                    ForEach(1...5, id: \.self) { i in
                        Image(systemName: i <= stars ? "star.fill" : "star")
                            .font(.system(size: 34))
                            .foregroundStyle(i <= stars ? BSColor.gold : BSColor.line)
                            .onTapGesture { withAnimation(.easeOut(duration: 0.1)) { stars = i } }
                            .accessibilityLabel("\(i) star\(i == 1 ? "" : "s")")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, BSSpace.m)

                BSField(label: "Add a note (optional)", placeholder: "Friendly, on time…", text: $comment)

                Spacer()
                BSButton(title: "Submit rating", isLoading: busy) {
                    busy = true
                    Task { await onSubmit(stars, comment.isEmpty ? nil : comment); dismiss() }
                }
            }
            .padding(.horizontal, BSSpace.xl)
            .padding(.bottom, BSSpace.xl)
            .background(BSColor.paper)
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.tint(BSColor.rust)
            } }
        }
        .tint(BSColor.rust)
    }
}
