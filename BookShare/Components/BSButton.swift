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
    var isLoading: Bool = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: BSSpace.s) {
                if isLoading {
                    ProgressView().tint(foreground)
                } else {
                    if let icon { Image(systemName: icon) }
                    Text(title)
                }
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
            .opacity(isEnabled && !isLoading ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
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
