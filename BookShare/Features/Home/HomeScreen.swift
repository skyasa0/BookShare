//
//  HomeScreen.swift
//  BookShare
//
//  The loan queue — everything in flight, borrowing and lending. Attention
//  lives here (not on tabs). The app is the nag (§07): reminders come from
//  the product's voice so neighbors only exchange the pleasant parts.
//

import SwiftUI

struct HomeScreen: View {
    // Loans are a later phase (no loans table yet). In offline preview we still
    // show the sample queue to exercise the loan UI; live mode shows an empty state.
    private var loans: [Loan] { AppLaunch.offlinePreview ? SampleData.homeQueue : [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BSSpace.l) {
                Text("Home")
                    .font(BSFont.title)
                    .foregroundStyle(BSColor.ink)
                    .padding(.top, BSSpace.s)

                if loans.isEmpty {
                    HomeEmptyState()
                } else {
                    NudgeBanner()
                    Text("Your loans")
                        .font(BSFont.serif(18, .bold))
                        .foregroundStyle(BSColor.ink)
                        .padding(.top, BSSpace.xs)
                    ForEach(loans) { loan in
                        LoanRow(loan: loan)
                    }
                }
            }
            .padding(.horizontal, BSSpace.xl)
            .padding(.bottom, BSSpace.xl)
        }
        .background(BSColor.paper)
    }
}

private struct HomeEmptyState: View {
    var body: some View {
        VStack(spacing: BSSpace.m) {
            Spacer(minLength: 80)
            Image(systemName: "tray").font(.system(size: 34)).foregroundStyle(BSColor.muted)
            Text("No loans in flight")
                .font(BSFont.serif(19, .bold)).foregroundStyle(BSColor.ink)
            Text("When you request a book from a neighbor — or someone asks for one of yours — it'll show up here, from request to return.")
                .font(BSFont.body).foregroundStyle(BSColor.muted)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct NudgeBanner: View {
    var body: some View {
        HStack(spacing: BSSpace.m) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 18))
                .foregroundStyle(BSColor.rust)
            VStack(alignment: .leading, spacing: 2) {
                Text("Klara and the Sun is due in 9 days")
                    .font(BSFont.sans(13.5, .semibold))
                    .foregroundStyle(BSColor.ink)
                Text("We'll nudge you 3 days before — no one has to be the nag.")
                    .font(BSFont.sans(12.5))
                    .foregroundStyle(BSColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(BSSpace.l)
        .background(BSColor.rustSoft.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: BSRadius.m))
    }
}

private struct LoanRow: View {
    let loan: Loan

    private var lifecycleIndex: Int {
        LoanStatus.lifecycle.firstIndex(of: loan.status) ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BSSpace.m) {
            HStack(spacing: BSSpace.m) {
                BookCover(color: loan.book.coverColor, title: loan.book.title,
                          width: 44, height: 58)
                VStack(alignment: .leading, spacing: 2) {
                    Text(loan.book.title)
                        .font(BSFont.cardTitle)
                        .foregroundStyle(BSColor.ink)
                        .lineLimit(1)
                    Text(loan.isLender ? "Lending to \(loan.counterparty)"
                                       : "Borrowing from \(loan.counterparty)")
                        .font(BSFont.sans(12.5))
                        .foregroundStyle(BSColor.rust)
                    if let due = loan.dueLabel {
                        Text(due).font(BSFont.mono(11.5)).foregroundStyle(BSColor.muted)
                    }
                }
                Spacer(minLength: 0)
                BSStatusBadge(status: loan.status)
            }

            BSLoanStepper(currentIndex: lifecycleIndex)
                .padding(.horizontal, 2)

            // Contextual action reflecting the current stage.
            actionButton
        }
        .padding(BSSpace.l)
        .background(BSColor.card)
        .clipShape(RoundedRectangle(cornerRadius: BSRadius.m + 1))
        .overlay(
            RoundedRectangle(cornerRadius: BSRadius.m + 1)
                .strokeBorder(BSColor.line, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var actionButton: some View {
        switch loan.status {
        case .requested:
            BSButton(title: "Awaiting response · 48h", style: .ghost) {}
        case .accepted:
            BSButton(title: "Plan the handoff", icon: "bubble.left.and.bubble.right.fill") {}
        case .onLoan:
            BSButton(title: loan.isLender ? "Mark returned" : "Message neighbor",
                     style: .ghost) {}
        default:
            EmptyView()
        }
    }
}

#Preview { HomeScreen() }
