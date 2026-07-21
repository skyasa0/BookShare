//
//  BSChip.swift
//  BookShare
//
//  Single-select genre filter chips. Selected chip inverts to terracotta.
//  Horizontal scroll past four. (Deliverable 14 §04)
//

import SwiftUI

struct BSChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BSFont.sans(13.5, .semibold))
                .foregroundStyle(isOn ? BSColor.onRust : BSColor.ink)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(isOn ? BSColor.rust : BSColor.card)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(isOn ? BSColor.rust : BSColor.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Horizontal single-select filter row.
struct BSChipRow<T: Hashable & Identifiable>: View {
    let items: [T]
    let title: (T) -> String
    @Binding var selection: T

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BSSpace.s) {
                ForEach(items) { item in
                    BSChip(title: title(item), isOn: item == selection) {
                        withAnimation(.easeOut(duration: 0.15)) { selection = item }
                    }
                }
            }
            .padding(.horizontal, BSSpace.xl)
        }
    }
}

#Preview {
    struct Demo: View {
        @State var sel: Book.Genre = .all
        var body: some View {
            BSChipRow(items: Book.Genre.allCases, title: { $0.rawValue }, selection: $sel)
                .padding(.vertical, 24)
                .frame(maxHeight: .infinity)
                .background(BSColor.paper)
        }
    }
    return Demo()
}
