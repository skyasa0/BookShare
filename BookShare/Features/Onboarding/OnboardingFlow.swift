//
//  OnboardingFlow.swift
//  BookShare
//
//  Pre-auth flow (Deliverable 10/11): welcome → choose method → email or phone.
//  Apple/Google use Supabase web OAuth. The app absorbs the awkwardness (§07):
//  privacy promises are stated plainly, right where the risk is felt.
//
//  After authentication the auth state advances to `.needsLocation`, and RootView
//  swaps in LocationStep — so this file ends at "signed in", not "onboarded".
//

import SwiftUI

struct OnboardingFlow: View {
    @State private var path: [Route] = []

    enum Route: Hashable { case methods, email, phone, otp(phone: String) }

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeScreen(onStart: { path.append(.methods) })
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .methods:          AuthMethodsScreen(path: $path)
                    case .email:            EmailAuthScreen()
                    case .phone:            PhoneAuthScreen(path: $path)
                    case .otp(let phone):   OTPScreen(phone: phone)
                    }
                }
        }
        .tint(BSColor.rust)
    }
}

// MARK: - Welcome

private struct WelcomeScreen: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BSSpace.l) {
            Spacer()
            HStack(spacing: 6) {
                ForEach(["8E6F4E", "6B4A3A", "55663F", "A8431F", "3E5266"], id: \.self) { hex in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: hex))
                        .frame(width: 30, height: [66, 92, 78, 96, 72][["8E6F4E","6B4A3A","55663F","A8431F","3E5266"].firstIndex(of: hex)!])
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
            BSButton(title: "Get started", action: onStart)
        }
        .padding(.horizontal, BSSpace.xl)
        .padding(.vertical, BSSpace.xl)
        .bsScreen()
    }
}

// MARK: - Method chooser

private struct AuthMethodsScreen: View {
    @Binding var path: [OnboardingFlow.Route]
    @Environment(AuthService.self) private var auth
    @State private var oauthBusy: AuthService.OAuthProvider?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: BSSpace.m) {
            Text("Join your\nneighborhood")
                .font(BSFont.display)
                .foregroundStyle(BSColor.ink)
                .padding(.top, BSSpace.s)
                .padding(.bottom, BSSpace.s)

            BSButton(title: "Continue with Apple", icon: "apple.logo", style: .ghost,
                     isLoading: oauthBusy == .apple) { oauth(.apple) }
            BSButton(title: "Continue with Google", icon: "g.circle", style: .ghost,
                     isLoading: oauthBusy == .google) { oauth(.google) }

            HStack {
                Rectangle().fill(BSColor.line).frame(height: 1)
                Text("or").font(BSFont.sans(12)).foregroundStyle(BSColor.muted)
                Rectangle().fill(BSColor.line).frame(height: 1)
            }.padding(.vertical, BSSpace.xs)

            BSButton(title: "Continue with email", icon: "envelope") { path.append(.email) }
            BSButton(title: "Continue with phone", icon: "phone", style: .ghost) { path.append(.phone) }

            if let error {
                Text(error).font(BSFont.sans(13)).foregroundStyle(BSColor.rustDeep)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            PrivacyNote("We verify every neighbor and never show your exact address. You choose what to share.")
        }
        .padding(.horizontal, BSSpace.xl)
        .padding(.bottom, BSSpace.xl)
        .bsScreen()
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }

    private func oauth(_ provider: AuthService.OAuthProvider) {
        oauthBusy = provider; error = nil
        Task {
            do { try await auth.signIn(with: provider) }
            catch {
                self.error = "\(provider.label) sign-in isn't configured yet. Add its keys in Supabase (see SETUP.md), or use email or phone."
            }
            oauthBusy = nil
        }
    }
}

// MARK: - Email (sign up / sign in + forgot password)

private struct EmailAuthScreen: View {
    @Environment(AuthService.self) private var auth
    @State private var isSignUp = true
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var notice: String?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BSSpace.l) {
                Text(isSignUp ? "Create your account" : "Welcome back")
                    .font(BSFont.display)
                    .foregroundStyle(BSColor.ink)
                    .padding(.top, BSSpace.s)

                if isSignUp {
                    BSField(label: "Name", placeholder: "Full name", text: $name)
                }
                BSField(label: "Email", placeholder: "you@email.com", text: $email, keyboard: .emailAddress)
                    .textInputAutocapitalization(.never)
                BSField(label: "Password", placeholder: "At least 6 characters", text: $password, secure: true)

                if !isSignUp {
                    Button("Forgot password?") { sendReset() }
                        .font(BSFont.sans(13, .semibold))
                        .foregroundStyle(BSColor.rust)
                }

                if let notice {
                    InlineBanner(text: notice, tone: .positive)
                }
                if let error {
                    InlineBanner(text: error, tone: .attention)
                }

                BSButton(title: isSignUp ? "Create account" : "Log in", isLoading: busy) { submit() }

                Button(isSignUp ? "I already have an account" : "Create a new account") {
                    withAnimation { isSignUp.toggle(); notice = nil; error = nil }
                }
                .font(BSFont.sans(14, .semibold))
                .foregroundStyle(BSColor.rust)
                .frame(maxWidth: .infinity)

                if isSignUp {
                    PrivacyNote("Your email is only used to sign in and send loan reminders — never shown to other neighbors.")
                }
            }
            .padding(.horizontal, BSSpace.xl)
            .padding(.bottom, BSSpace.xl)
        }
        .bsScreen()
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        busy = true; error = nil; notice = nil
        Task {
            do {
                if isSignUp {
                    try await auth.signUpEmail(name: name, email: email, password: password)
                } else {
                    try await auth.signInEmail(email: email, password: password)
                }
                // On success, auth.state advances and RootView swaps the screen.
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }

    private func sendReset() {
        guard !email.isEmpty else { error = "Enter your email above first, then tap Forgot password."; return }
        error = nil
        Task {
            do {
                try await auth.sendPasswordReset(email: email)
                notice = "Check your email for a reset link. (Local dev: it's in Mailpit at 127.0.0.1:54324.)"
            } catch { self.error = error.localizedDescription }
        }
    }
}

// MARK: - Phone → OTP

private struct PhoneAuthScreen: View {
    @Binding var path: [OnboardingFlow.Route]
    @Environment(AuthService.self) private var auth
    @State private var phone = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: BSSpace.l) {
            Text("What's your\nphone number?")
                .font(BSFont.display)
                .foregroundStyle(BSColor.ink)
                .padding(.top, BSSpace.s)

            BSField(label: "Phone", placeholder: "+1 (555) 555-0100", text: $phone, keyboard: .phonePad)

            if let error { InlineBanner(text: error, tone: .attention) }

            BSButton(title: "Send verification code", isLoading: busy) { send() }
            Spacer()
            PrivacyNote("We text a one-time code to confirm your number. It's never shown on your listings.")
        }
        .padding(.horizontal, BSSpace.xl)
        .padding(.bottom, BSSpace.xl)
        .bsScreen()
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }

    private func send() {
        busy = true; error = nil
        Task {
            do {
                try await auth.startPhoneOTP(phone: phone)
                path.append(.otp(phone: phone))
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}

private struct OTPScreen: View {
    let phone: String
    @Environment(AuthService.self) private var auth
    @State private var code = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: BSSpace.l) {
            BSStepChip(current: 2, total: 2).padding(.top, BSSpace.s)
            Text("Enter the code")
                .font(BSFont.display)
                .foregroundStyle(BSColor.ink)
            Text("We sent a 6-digit code to \(phone).")
                .font(BSFont.body).foregroundStyle(BSColor.muted)

            BSField(label: "Verification code", placeholder: "123456", text: $code, keyboard: .numberPad)

            if let error { InlineBanner(text: error, tone: .attention) }

            BSButton(title: "Verify", isLoading: busy) { verify() }
            Spacer()
        }
        .padding(.horizontal, BSSpace.xl)
        .padding(.bottom, BSSpace.xl)
        .bsScreen()
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }

    private func verify() {
        busy = true; error = nil
        Task {
            do { try await auth.verifyPhoneOTP(phone: phone, code: code) }
            catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}

// MARK: - Shared bits

/// Sage/attention inline message under a form.
struct InlineBanner: View {
    enum Tone { case positive, attention }
    let text: String
    let tone: Tone
    var body: some View {
        HStack(alignment: .top, spacing: BSSpace.s) {
            Image(systemName: tone == .positive ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(tone == .positive ? BSColor.sage : BSColor.rustDeep)
            Text(text).font(BSFont.sans(13)).foregroundStyle(BSColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(BSSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((tone == .positive ? BSColor.sageBg : BSColor.rustSoft).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: BSRadius.m))
    }
}

struct PrivacyNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack(alignment: .top, spacing: BSSpace.s) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12)).foregroundStyle(BSColor.sage).padding(.top, 2)
            Text(text)
                .font(BSFont.sans(13)).foregroundStyle(BSColor.muted)
                .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(BSSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BSColor.sageBg.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: BSRadius.m))
    }
}
