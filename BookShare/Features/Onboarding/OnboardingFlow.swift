//
//  OnboardingFlow.swift
//  BookShare
//
//  Welcome + 2-step onboarding (Deliverable 10/11). The app absorbs the
//  awkwardness (§07): privacy promises are stated in plain sentences, right
//  where the risk is felt.
//

import SwiftUI

struct OnboardingFlow: View {
    /// Called when the neighbor finishes onboarding.
    let onFinish: () -> Void

    private enum Stage { case welcome, details, address }
    @State private var stage: Stage = .welcome

    @State private var name = ""
    @State private var phone = ""
    @State private var address = ""

    var body: some View {
        ZStack {
            BSColor.paper.ignoresSafeArea()
            switch stage {
            case .welcome:
                WelcomeScreen { withAnimation { stage = .details } }
                    .transition(.opacity)
            case .details:
                DetailsScreen(name: $name, phone: $phone,
                              onBack: { withAnimation { stage = .welcome } },
                              onNext: { withAnimation { stage = .address } })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .address:
                AddressScreen(address: $address,
                              onBack: { withAnimation { stage = .details } },
                              onFinish: onFinish)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Welcome

private struct WelcomeScreen: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BSSpace.l) {
            Spacer()
            // Little "shelf" motif from stacked covers.
            HStack(spacing: 6) {
                ForEach(["8E6F4E", "6B4A3A", "55663F", "A8431F", "3E5266"], id: \.self) { hex in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: hex))
                        .frame(width: 30, height: CGFloat.random(in: 66...96))
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, BSSpace.xl)

            Text("BookShare")
                .font(BSFont.serif(40, .bold))
                .foregroundStyle(BSColor.ink)
            Text("Borrow and lend books with the neighbors right around you. No marketplace, no strangers — just shelves down the street.")
                .font(BSFont.sans(16))
                .foregroundStyle(BSColor.muted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            BSButton(title: "Create account", action: onStart)
            BSButton(title: "I already have an account", style: .quiet, action: onStart)
        }
        .padding(.horizontal, BSSpace.xl)
        .padding(.vertical, BSSpace.xl)
    }
}

// MARK: - Step 1 · details

private struct DetailsScreen: View {
    @Binding var name: String
    @Binding var phone: String
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        OnboardingScaffold(step: 1, title: "First, the basics", onBack: onBack) {
            VStack(alignment: .leading, spacing: BSSpace.l) {
                BSField(label: "Name", placeholder: "Full name", text: $name)
                BSField(label: "Phone", placeholder: "+1 (___) ___-____",
                        text: $phone, keyboard: .phonePad)
                PrivacyNote("We verify your number so neighbors know you're real. It's never shown on your listings.")
            }
        } footer: {
            BSButton(title: "Continue", action: onNext)
        }
    }
}

// MARK: - Step 2 · address

private struct AddressScreen: View {
    @Binding var address: String
    let onBack: () -> Void
    let onFinish: () -> Void

    var body: some View {
        OnboardingScaffold(step: 2, title: "Where do you live?", onBack: onBack) {
            VStack(alignment: .leading, spacing: BSSpace.l) {
                Text("We use your location to find books nearby. Your exact address is never shown to other users.")
                    .font(BSFont.body)
                    .foregroundStyle(BSColor.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                BSButton(title: "Use current location", icon: "location.fill",
                         style: .ghost) { address = "Cobble Hill, Brooklyn" }

                HStack {
                    Rectangle().fill(BSColor.line).frame(height: 1)
                    Text("or enter it").font(BSFont.sans(12)).foregroundStyle(BSColor.muted)
                    Rectangle().fill(BSColor.line).frame(height: 1)
                }
                .padding(.vertical, 4)

                BSField(label: "Home address", placeholder: "Street, city", text: $address)
                PrivacyNote("Neighbors only ever see an approximate distance — like \"0.3 mi\" — computed on our servers.")
            }
        } footer: {
            BSButton(title: "Finish setup", action: onFinish)
        }
    }
}

// MARK: - Shared scaffold + privacy note

private struct OnboardingScaffold<Content: View, Footer: View>: View {
    let step: Int
    let title: String
    let onBack: () -> Void
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(BSColor.ink)
                        .frame(width: 44, height: 44, alignment: .leading)
                }
                Spacer()
                BSStepChip(current: step, total: 2)
            }
            .padding(.top, BSSpace.s)

            Text(title)
                .font(BSFont.display)
                .foregroundStyle(BSColor.ink)
                .padding(.top, BSSpace.l)
                .padding(.bottom, BSSpace.xl)

            content
            Spacer()
            footer
        }
        .padding(.horizontal, BSSpace.xl)
        .padding(.bottom, BSSpace.xl)
    }
}

private struct PrivacyNote: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .top, spacing: BSSpace.s) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundStyle(BSColor.sage)
                .padding(.top, 2)
            Text(text)
                .font(BSFont.sans(13))
                .foregroundStyle(BSColor.muted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(BSSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BSColor.sageBg.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: BSRadius.m))
    }
}

#Preview { OnboardingFlow(onFinish: {}) }
