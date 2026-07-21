//
//  BSStepper.swift
//  BookShare
//
//  Step chip & loan stepper (Deliverable 14 §04). Onboarding progress uses the
//  mono step chip. Loan lifecycle uses a 4-node stepper with the global
//  vocabulary — completed nodes get checks.
//

import SwiftUI

/// Mono onboarding progress chip, e.g. "Step 1 of 2".
struct BSStepChip: View {
    let current: Int
    let total: Int

    var body: some View {
        Text("Step \(current) of \(total)")
            .font(BSFont.mono(12, .semibold))
            .foregroundStyle(Color(hex: "FBF3E4"))
            .padding(.vertical, 5)
            .padding(.horizontal, 12)
            .background(BSColor.rust)
            .clipShape(Capsule())
    }
}

/// 4-node loan lifecycle stepper. Nodes at or before `currentIndex` are done.
struct BSLoanStepper: View {
    /// Index into LoanStatus.lifecycle for the current stage.
    let currentIndex: Int

    private let nodes = LoanStatus.lifecycle

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(nodes.enumerated()), id: \.offset) { i, _ in
                node(index: i)
                if i < nodes.count - 1 {
                    Rectangle()
                        .fill(i < currentIndex ? BSColor.rust : Color(hex: "DCD2BD"))
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func node(index i: Int) -> some View {
        let done = i < currentIndex
        let active = i == currentIndex
        ZStack {
            Circle()
                .fill(done || active ? BSColor.rust : Color(hex: "DCD2BD"))
                .frame(width: 26, height: 26)
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Text("\(i + 1)")
                    .font(BSFont.sans(12, .bold))
                    .foregroundStyle(active ? .white : Color(hex: "8B7B63"))
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 28) {
        BSStepChip(current: 1, total: 2)
        BSLoanStepper(currentIndex: 2)
        BSLoanStepper(currentIndex: 0)
    }
    .padding(BSSpace.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BSColor.paper)
}
