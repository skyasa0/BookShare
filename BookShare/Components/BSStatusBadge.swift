//
//  BSStatusBadge.swift
//  BookShare
//
//  The global loan vocabulary (§05), rendered. Sage = actionable-positive,
//  neutral = passive, terracotta tint = needs attention. Never more than one
//  badge per card. Every color signal is paired with its text label.
//

import SwiftUI

struct BSStatusBadge: View {
    let status: LoanStatus

    var body: some View {
        Text(status.rawValue)
            .font(BSFont.sans(11.5, .semibold))
            .foregroundStyle(status.foreground)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(status.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Trust signal: verified check + rating (e.g. "✓ Verified · ★4.8").
struct BSVerifiedBadge: View {
    var rating: Double? = nil
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill")
            Text("Verified")
            if let rating {
                Text("· ★\(String(format: "%.1f", rating))")
            }
        }
        .font(BSFont.sans(10.5, .semibold))
        .foregroundStyle(BSColor.sage)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(BSColor.sageBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    VStack(spacing: 12) {
        HStack(spacing: 10) {
            ForEach(LoanStatus.allCases) { BSStatusBadge(status: $0) }
        }
        BSVerifiedBadge(rating: 4.8)
    }
    .padding(BSSpace.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BSColor.paper)
}
