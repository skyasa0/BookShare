//
//  ProfileScreen.swift
//  BookShare
//
//  Your neighbor identity: avatar, verified badge, reliability rating. Backed by
//  the signed-in user's profile row. Verification is optional (BRD).
//

import SwiftUI

struct ProfileScreen: View {
    @Environment(AuthService.self) private var auth
    @State private var listedCount: Int?
    @State private var signingOut = false

    private let repo = BooksRepository()

    private var name: String {
        let n = auth.displayName.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "Neighbor" : n
    }
    private var subtitle: String {
        auth.profile?.neighborhood ?? auth.accountLabel
    }
    private var initials: String {
        let parts = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return parts.isEmpty ? "?" : parts.map(String.init).joined().uppercased()
    }
    private var rating: Double { auth.profile?.rating ?? 5.0 }
    private var verified: Bool { auth.profile?.verified ?? false }

    var body: some View {
        ScrollView {
            VStack(spacing: BSSpace.l) {
                // Identity header
                VStack(spacing: BSSpace.m) {
                    ZStack {
                        Circle().fill(BSColor.rust)
                        Text(initials).font(BSFont.serif(30, .bold)).foregroundStyle(.white)
                    }
                    .frame(width: 92, height: 92)
                    .overlay(Circle().strokeBorder(BSColor.gold, lineWidth: 2))

                    VStack(spacing: 4) {
                        Text(name).font(BSFont.serif(24, .bold)).foregroundStyle(BSColor.ink)
                        if !subtitle.isEmpty {
                            Text(subtitle).font(BSFont.mono(12)).foregroundStyle(BSColor.muted)
                        }
                    }
                    if verified {
                        BSVerifiedBadge(rating: rating)
                    } else {
                        BSStatusBadge(status: .requested).opacity(0)  // spacer parity
                    }
                }
                .padding(.top, BSSpace.l)

                HStack(spacing: BSSpace.m) {
                    ProfileStat(value: listedCount.map(String.init) ?? "—", label: "Listed")
                    ProfileStat(value: String(format: "%.1f", rating), label: "Rating", gold: true)
                }

                // Settings list
                VStack(spacing: 0) {
                    ProfileRow(icon: "checkmark.seal", title: "Verify your ID",
                               detail: verified ? "Verified Neighbor" : "Get the Verified Neighbor badge")
                    Divider().background(BSColor.line)
                    ProfileRow(icon: "location", title: "Location & radius",
                               detail: "Within 2 mi of you")
                    Divider().background(BSColor.line)
                    ProfileRow(icon: "bell", title: "Reminders", detail: "Due-date nudges on")
                    Divider().background(BSColor.line)
                    ProfileRow(icon: "envelope", title: "Account", detail: auth.accountLabel.isEmpty ? "Signed in" : auth.accountLabel)
                }
                .background(BSColor.card)
                .clipShape(RoundedRectangle(cornerRadius: BSRadius.m))
                .overlay(
                    RoundedRectangle(cornerRadius: BSRadius.m).strokeBorder(BSColor.line, lineWidth: 1)
                )

                BSButton(title: "Sign out", style: .quiet, isLoading: signingOut) {
                    signingOut = true
                    Task { await auth.signOut() }
                }
            }
            .padding(.horizontal, BSSpace.xl)
            .padding(.bottom, BSSpace.xl)
        }
        .background(BSColor.paper)
        .task {
            listedCount = (try? await repo.myShelf())?.count
        }
    }
}

private struct ProfileStat: View {
    let value: String
    let label: String
    var gold: Bool = false
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                if gold { Image(systemName: "star.fill").font(.system(size: 13)).foregroundStyle(BSColor.gold) }
                Text(value).font(BSFont.serif(22, .bold)).foregroundStyle(BSColor.ink)
            }
            Text(label).font(BSFont.sans(11.5, .medium)).foregroundStyle(BSColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BSSpace.m)
        .background(BSColor.card)
        .clipShape(RoundedRectangle(cornerRadius: BSRadius.m))
        .overlay(RoundedRectangle(cornerRadius: BSRadius.m).strokeBorder(BSColor.line, lineWidth: 1))
    }
}

private struct ProfileRow: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        HStack(spacing: BSSpace.m) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(BSColor.rust)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(BSFont.sans(15, .semibold)).foregroundStyle(BSColor.ink)
                Text(detail).font(BSFont.sans(12.5)).foregroundStyle(BSColor.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BSColor.muted)
        }
        .padding(BSSpace.l)
        .contentShape(Rectangle())
    }
}
