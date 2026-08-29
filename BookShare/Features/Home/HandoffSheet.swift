//
//  HandoffSheet.swift
//  BookShare
//
//  In-app handoff coordination (the primary path — no chat, no number sharing):
//  propose a spot + time; the other neighbor confirms. A couple of neighborly
//  presets plus free text keeps it one-tap-fast.
//

import SwiftUI

struct HandoffSheet: View {
    let loan: Loan
    /// (place, time) -> perform. Called on submit; the sheet then dismisses.
    let onPropose: (String, Date) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var place = ""
    @State private var time = Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date()
    @State private var busy = false

    private let presets = ["My stoop", "The corner café", "The library steps", "Outside the subway"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BSSpace.l) {
                    Text("Arrange the handoff")
                        .font(BSFont.display).foregroundStyle(BSColor.ink).padding(.top, BSSpace.s)
                    Text("Suggest where and when to meet \(loan.counterparty). They'll confirm — no numbers shared.")
                        .font(BSFont.body).foregroundStyle(BSColor.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("A SPOT").bsFieldLabel()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: BSSpace.s) {
                            ForEach(presets, id: \.self) { p in
                                BSChip(title: p, isOn: place == p) {
                                    withAnimation(.easeOut(duration: 0.15)) { place = p }
                                }
                            }
                        }
                    }
                    BSField(label: "Or somewhere else", placeholder: "Cross streets or a landmark", text: $place)

                    VStack(alignment: .leading, spacing: BSSpace.s) {
                        Text("WHEN").bsFieldLabel()
                        DatePicker("", selection: $time, in: Date()...)
                            .datePickerStyle(.compact).labelsHidden().tint(BSColor.rust)
                    }

                    PrivacyNote("Prefer to chat it through? You can message on WhatsApp from the loan once it's accepted.")
                }
                .padding(.horizontal, BSSpace.xl)
                .padding(.bottom, BSSpace.xl)
            }
            .background(BSColor.paper)
            .safeAreaInset(edge: .bottom) {
                BSButton(title: "Send proposal", isLoading: busy) {
                    busy = true
                    Task { await onPropose(place.trimmingCharacters(in: .whitespaces), time); dismiss() }
                }
                .disabled(place.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(BSSpace.xl)
                .background(BSColor.paper)
            }
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.tint(BSColor.rust)
            } }
        }
        .tint(BSColor.rust)
    }
}
