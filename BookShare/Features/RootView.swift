//
//  RootView.swift
//  BookShare
//
//  Top-level routing, driven by AuthService.state:
//    loading → splash · signedOut → onboarding · needsLocation → address step · ready → tabs
//

import SwiftUI

/// Launch-time flags. `BOOTSTRAP=discover|home|shelf|profile` opens the tab shell
/// on sample data with no backend — handy for UI work without the stack running.
enum AppLaunch {
    private static func env(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key]?.lowercased()
    }
    /// BOOTSTRAP forces the offline sample-data shell (no backend).
    static var offlinePreview: Bool { env("BOOTSTRAP") != nil }
    /// START_TAB picks the initial tab on the real (signed-in) app; BOOTSTRAP does the same for offline.
    static var tab: AppTab {
        switch env("BOOTSTRAP") ?? env("START_TAB") {
        case "home":    return .home
        case "shelf":   return .shelf
        case "profile": return .profile
        default:        return .discover
        }
    }
    /// SCAN_DEMO auto-opens the scanner on the Shelf (for screenshot verification).
    static var scanDemo: Bool { env("SCAN_DEMO") != nil }
}

struct RootView: View {
    @Environment(AuthService.self) private var auth
    @State private var tab: AppTab = AppLaunch.tab

    var body: some View {
        Group {
            if AppLaunch.offlinePreview {
                MainShell(tab: $tab)                 // sample-data UI, no auth
            } else {
                switch auth.state {
                case .loading:       SplashView()
                case .signedOut:     OnboardingFlow()
                case .needsLocation: LocationStep()
                case .ready:         MainShell(tab: $tab)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: auth.state)
    }
}

private struct SplashView: View {
    var body: some View {
        ZStack {
            BSColor.paper.ignoresSafeArea()
            VStack(spacing: BSSpace.l) {
                HStack(spacing: 5) {
                    ForEach(["8E6F4E", "6B4A3A", "55663F", "A8431F", "3E5266"], id: \.self) { hex in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: hex))
                            .frame(width: 18, height: 52)
                    }
                }
                Text("BookShare")
                    .font(BSFont.serif(26, .bold))
                    .foregroundStyle(BSColor.ink)
                ProgressView().tint(BSColor.rust)
            }
        }
    }
}

struct MainShell: View {
    @Binding var tab: AppTab

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .discover: DiscoverScreen()
                case .home:     HomeScreen()
                case .shelf:    ShelfScreen()
                case .profile:  ProfileScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BSTabBar(selection: $tab)
        }
        .background(BSColor.paper)
    }
}
