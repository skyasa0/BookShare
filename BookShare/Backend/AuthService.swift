//
//  AuthService.swift
//  BookShare
//
//  Observable auth state + the Phase-1 auth surface: email/password (with
//  reset), phone OTP, and Apple/Google OAuth. Drives the app's top-level
//  routing via `state` (see RootView).
//

import Foundation
import Supabase

@MainActor
@Observable
final class AuthService {

    enum State: Equatable {
        case loading       // resolving persisted session on launch
        case signedOut     // show onboarding / auth
        case needsLocation // authenticated but no home location yet
        case ready         // authenticated + located → main app
    }

    enum OAuthProvider { case apple, google
        var sdk: Provider { self == .apple ? .apple : .google }
        var label: String { self == .apple ? "Apple" : "Google" }
    }

    private(set) var state: State = .loading
    /// The signed-in user's profile row (nil while loading / signed out).
    private(set) var profile: ProfileDTO?
    /// Display name for the signed-in user (from profile / signup metadata).
    var displayName: String { profile?.name ?? "" }
    /// Email/phone identity for display.
    private(set) var accountLabel: String = ""

    private let client = SupabaseManager.client
    private var watchTask: Task<Void, Never>?

    init() {
        // Observe auth changes (initial session, sign-in, sign-out, recovery…).
        watchTask = Task { [weak self] in
            guard let self else { return }
            for await change in client.auth.authStateChanges {
                await self.resolveState(session: change.session)
            }
        }
    }

    // MARK: - State resolution

    private func resolveState(session: Session?) async {
        guard let session else {
            profile = nil
            accountLabel = ""
            state = .signedOut
            return
        }
        accountLabel = session.user.email ?? session.user.phone ?? ""
        // Signed in — do we have a home location yet?
        do {
            let p = try await fetchProfile()
            profile = p
            state = (p.home_location == nil) ? .needsLocation : .ready
        } catch {
            // Couldn't read the profile row (e.g. just created) — treat as
            // signed-in-but-unlocated so onboarding continues to the address step.
            profile = nil
            state = .needsLocation
        }
    }

    /// Re-read the profile (e.g. after setting location) without changing routing.
    func reloadProfile() async {
        profile = try? await fetchProfile()
    }

    private func fetchProfile() async throws -> ProfileDTO {
        try await client
            .from("profiles")
            .select("id,name,neighborhood,verified,rating,home_location")
            .single()
            .execute()
            .value
    }

    // MARK: - Email / password

    func signUpEmail(name: String, email: String, password: String) async throws {
        try await client.auth.signUp(
            email: email,
            password: password,
            data: ["name": .string(name)]
        )
        // authStateChanges will fire and advance `state`.
    }

    func signInEmail(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func sendPasswordReset(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email, redirectTo: SupabaseConfig.redirectURL)
    }

    // MARK: - Phone OTP (SMS verification)

    func startPhoneOTP(phone: String) async throws {
        try await client.auth.signInWithOTP(phone: normalizedPhone(phone))
    }

    func verifyPhoneOTP(phone: String, code: String) async throws {
        try await client.auth.verifyOTP(phone: normalizedPhone(phone), token: code, type: .sms)
    }

    /// Strip spaces/dashes/parens so "+1 (555) 555-0100" → "+15555550100".
    private func normalizedPhone(_ raw: String) -> String {
        var s = raw.filter { $0.isNumber || $0 == "+" }
        if !s.hasPrefix("+") { s = "+" + s }
        return s
    }

    // MARK: - OAuth (scaffolded; needs provider config — see SETUP.md)

    func signIn(with provider: OAuthProvider) async throws {
        try await client.auth.signInWithOAuth(
            provider: provider.sdk,
            redirectTo: SupabaseConfig.redirectURL
        )
    }

    // MARK: - Location

    /// Persist the caller's home location, then advance to `.ready`.
    func setHomeLocation(lat: Double, lng: Double) async throws {
        try await client
            .rpc("update_my_location", params: ["lat": lat, "lng": lng])
            .execute()
        await reloadProfile()
        state = .ready
    }

    // MARK: - Sign out

    func signOut() async {
        try? await client.auth.signOut()
        state = .signedOut
    }
}

/// Owner-visible profile row. `home_location` arrives as PostGIS EWKB hex (or
/// nil); we only nil-check it to decide whether onboarding needs the address step.
struct ProfileDTO: Decodable {
    let id: UUID
    let name: String
    let neighborhood: String?
    let verified: Bool
    let rating: Double
    let home_location: String?
}
