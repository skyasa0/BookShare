//
//  BSButton.swift
//  BookShare
//
//  One primary per screen, full-width on mobile. Ghost for secondary paths,
//  quiet for tertiary, low-commitment actions. (Deliverable 14 §04)
//

import SwiftUI

struct BSButton: View {
    enum Style { case primary, ghost, quiet }

    let title: String
    var icon: String? = nil
    var style: Style = .primary
    var fullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: BSSpace.s) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(BSFont.sans(15, style == .primary ? .bold : .semibold))
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 26)
            .padding(.vertical, 15)
            .padding(.horizontal, 30)
            .foregroundStyle(foreground)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: BSRadius.m)
                    .strokeBorder(border, lineWidth: style == .ghost ? 1 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: BSRadius.m))
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch style {
        case .primary: return BSColor.onRust
        case .ghost:   return BSColor.ink
        case .quiet:   return BSColor.rust
        }
    }
    private var background: Color {
        switch style {
        case .primary: return BSColor.rust
        case .ghost:   return BSColor.field
        case .quiet:   return .clear
        }
    }
    private var border: Color {
        style == .ghost ? BSColor.fieldLine : .clear
    }
}

#Preview {
    VStack(spacing: 16) {
        BSButton(title: "Create account") {}
        BSButton(title: "Use current location", icon: "location.fill", style: .ghost) {}
        BSButton(title: "Add to wishlist", icon: "heart", style: .quiet, fullWidth: false) {}
    }
    .padding(BSSpace.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BSColor.paper)
}
