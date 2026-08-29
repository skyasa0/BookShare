//
//  HomeScreen.swift
//  BookShare
//
//  The loan queue — everything in flight, borrowing and lending. Drives the
//  full lifecycle: accept/decline, arrange handoff (spot + time), mark returned,
//  and rate. Attention lives here, not on the tabs.
//

import SwiftUI

struct HomeScreen: View {
    @State private var loans: [Loan] = []
    @State private var phase: Phase = .loading
    @State private var handoffLoan: Loan?
    @State private var ratingLoan: Loan?
    @State private var busyID: UUID?

    private let repo = LoansRepository()
    enum Phase: Equatable { case loading, loaded, failed(String) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BSSpace.l) {
                Text("Home").font(BSFont.title).foregroundStyle(BSColor.ink).padding(.top, BSSpace.s)
                content
            }
            .padding(.horizontal, BSSpace.xl)
            .padding(.bottom, BSSpace.xl)
        }
        .background(BSColor.paper)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $handoffLoan) { loan in
            HandoffSheet(loan: loan) { place, time in
                await run(loan.id) { try await repo.proposeHandoff(loanID: loan.id, place: place, time: time) }
            }
        }
        .sheet(item: $ratingLoan) { loan in
            RatingSheet(loan: loan) { stars, comment in
                await run(loan.id) { try await repo.rate(loanID: loan.id, stars: stars, comment: comment) }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView().tint(BSColor.rust).frame(maxWidth: .infinity).padding(.top, 80)
        case .failed(let msg):
            InlineBanner(text: msg, tone: .attention)
        case .loaded where loans.isEmpty:
            HomeEmptyState()
        case .loaded:
            Text("Your loans").font(BSFont.serif(18, .bold)).foregroundStyle(BSColor.ink)
            ForEach(loans) { loan in
                LoanRow(loan: loan, busy: busyID == loan.id,
                        onAction: { handle($0, on: loan) })
            }
        }
    }

    // MARK: - Data

    private func load() async {
        if AppLaunch.offlinePreview { loans = SampleData.homeQueue; phase = .loaded; return }
        do { loans = try await repo.myLoans(); phase = .loaded }
        catch { phase = .failed(error.localizedDescription) }
    }

    private func handle(_ action: LoanAction, on loan: Loan) {
        switch action {
        case .accept:        Task { await run(loan.id) { try await repo.respond(loanID: loan.id, accept: true) } }
        case .decline:       Task { await run(loan.id) { try await repo.respond(loanID: loan.id, accept: false) } }
        case .confirmHandoff: Task { await run(loan.id) { try await repo.confirmHandoff(loanID: loan.id) } }
        case .markReturned:  Task { await run(loan.id) { try await repo.markReturned(loanID: loan.id) } }
        case .proposeHandoff: handoffLoan = loan
        case .rate:          ratingLoan = loan
        case .whatsApp:
            if let phone = loan.counterpartyPhone {
                WhatsApp.open(phone: phone,
                              message: WhatsApp.handoffMessage(book: loan.book.title, isLender: loan.isLender))
            }
        }
    }

    /// Runs a mutating repo call with a per-row spinner, then reloads.
    private func run(_ id: UUID, _ op: @escaping () async throws -> Void) async {
        busyID = id
        do { try await op() } catch { phase = .failed(error.localizedDescription) }
        await load()
        busyID = nil
    }
}

// MARK: - Loan row

enum LoanAction { case accept, decline, proposeHandoff, confirmHandoff, markReturned, rate, whatsApp }

private struct LoanRow: View {
    let loan: Loan
    var busy: Bool = false
    var onAction: (LoanAction) -> Void = { _ in }

    private var lifecycleIndex: Int { LoanStatus.lifecycle.firstIndex(of: loan.status) ?? 0 }
    private var showWhatsApp: Bool {
        loan.counterpartyPhone != nil && (loan.status == .accepted || loan.status == .onLoan)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BSSpace.m) {
            HStack(spacing: BSSpace.m) {
                BookCover(color: loan.book.coverColor, title: loan.book.title,
                          coverURL: loan.book.coverURL, width: 44, height: 58)
                VStack(alignment: .leading, spacing: 2) {
                    Text(loan.book.title).font(BSFont.cardTitle).foregroundStyle(BSColor.ink).lineLimit(1)
                    Text(loan.isLender ? "Lending to \(loan.counterparty)"
                                       : "Borrowing from \(loan.counterparty)")
                        .font(BSFont.sans(12.5)).foregroundStyle(BSColor.rust)
                    if let due = loan.dueLabel {
                        Text(due).font(BSFont.mono(11.5)).foregroundStyle(BSColor.muted)
                    }
                }
                Spacer(minLength: 0)
                BSStatusBadge(status: loan.status)
            }

            BSLoanStepper(currentIndex: lifecycleIndex).padding(.horizontal, 2)

            if loan.status == .accepted, let handoff = loan.handoffLabel {
                Label(handoff, systemImage: "mappin.and.ellipse")
                    .font(BSFont.sans(12.5, .medium)).foregroundStyle(BSColor.ink)
            }

            actions
        }
        .padding(BSSpace.l)
        .background(BSColor.card)
        .clipShape(RoundedRectangle(cornerRadius: BSRadius.m + 1))
        .overlay(RoundedRectangle(cornerRadius: BSRadius.m + 1).strokeBorder(BSColor.line, lineWidth: 1))
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: BSSpace.s) {
            switch loan.status {
            case .requested:
                if loan.isLender {
                    HStack(spacing: BSSpace.s) {
                        BSButton(title: "Decline", style: .ghost, isLoading: false) { onAction(.decline) }
                        BSButton(title: "Accept", isLoading: busy) { onAction(.accept) }
                    }
                } else {
                    BSButton(title: "Awaiting response · 48h", style: .ghost) {}.disabled(true)
                }

            case .accepted:
                if !loan.hasHandoffProposal {
                    BSButton(title: "Propose a spot & time", icon: "mappin.and.ellipse",
                             isLoading: busy) { onAction(.proposeHandoff) }
                } else if loan.handoffProposedByMe {
                    BSButton(title: "Waiting for \(loan.counterparty) to confirm", style: .ghost) {}
                        .disabled(true)
                } else {
                    BSButton(title: "Confirm handoff", icon: "checkmark", isLoading: busy) {
                        onAction(.confirmHandoff)
                    }
                }
                if showWhatsApp { whatsAppButton }

            case .onLoan:
                if loan.isLender {
                    BSButton(title: "Mark returned", isLoading: busy) { onAction(.markReturned) }
                }
                if showWhatsApp { whatsAppButton }

            case .returned:
                BSButton(title: "Rate your neighbor", icon: "star.fill", isLoading: busy) { onAction(.rate) }

            default:
                EmptyView()
            }
        }
    }

    private var whatsAppButton: some View {
        BSButton(title: "Message on WhatsApp", icon: "bubble.left.and.bubble.right.fill",
                 style: .quiet) { onAction(.whatsApp) }
    }
}

// MARK: - Empty state

private struct HomeEmptyState: View {
    var body: some View {
        VStack(spacing: BSSpace.m) {
            Spacer(minLength: 80)
            Image(systemName: "tray").font(.system(size: 34)).foregroundStyle(BSColor.muted)
            Text("No loans in flight").font(BSFont.serif(19, .bold)).foregroundStyle(BSColor.ink)
            Text("When you request a book from a neighbor — or someone asks for one of yours — it'll show up here, from request to return.")
                .font(BSFont.body).foregroundStyle(BSColor.muted)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}
