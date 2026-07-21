//
//  ProfileScreen.swift
//  BookShare
//
//  Your neighbor identity: avatar, verified badge, reliability rating, and the
//  loan history that earns trust. Verification is optional (BRD).
//

import SwiftUI

struct ProfileScreen: View {
    private let me = SampleData.me

    var body: some View {
        ScrollView {
            VStack(spacing: BSSpace.l) {
                // Identity header
                VStack(spacing: BSSpace.m) {
                    ZStack {
                        Circle().fill(me.avatarColor)
                        Text(me.initials)
                            .font(BSFont.serif(30, .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 92, height: 92)
                    .overlay(Circle().strokeBorder(BSColor.gold, lineWidth: 2))

                    VStack(spacing: 4) {
                        Text(me.name)
                            .font(BSFont.serif(24, .bold))
                            .foregroundStyle(BSColor.ink)
                        HStack(spacing: 4) {
                            Image(systemName: "scope").font(.system(size: 11))
                            Text(me.neighborhood)
                        }
                        .font(BSFont.mono(12))
                        .foregroundStyle(BSColor.muted)
                    }
                    if me.verified {
                        BSVerifiedBadge(rating: me.rating)
                    }
                }
                .padding(.top, BSSpace.l)

                HStack(spacing: BSSpace.m) {
                    ProfileStat(value: "\(me.loansGiven)", label: "Lent")
                    ProfileStat(value: "\(me.loansTaken)", label: "Borrowed")
                    ProfileStat(value: String(format: "%.1f", me.rating), label: "Rating", gold: true)
                }

                // Settings list
                VStack(spacing: 0) {
                    ProfileRow(icon: "checkmark.seal", title: "Verify your ID",
                               detail: "Get the Verified Neighbor badge")
                    Divider().background(BSColor.line)
                    ProfileRow(icon: "location", title: "Location & radius",
                               detail: "Within 2 mi of \(me.neighborhood)")
                    Divider().background(BSColor.line)
                    ProfileRow(icon: "bell", title: "Reminders", detail: "Due-date nudges on")
                    Divider().background(BSColor.line)
                    ProfileRow(icon: "heart", title: "Wishlist", detail: "3 books watched")
                }
                .background(BSColor.card)
                .clipShape(RoundedRectangle(cornerRadius: BSRadius.m))
                .overlay(
                    RoundedRectangle(cornerRadius: BSRadius.m).strokeBorder(BSColor.line, lineWidth: 1)
                )

                BSButton(title: "Sign out", style: .quiet) {}
            }
            .padding(.horizontal, BSSpace.xl)
            .padding(.bottom, BSSpace.xl)
        }
        .background(BSColor.paper)
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

#Preview { ProfileScreen() }
