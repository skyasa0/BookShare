//
//  RootView.swift
//  BookShare
//
//  The 4-tab shell (go_router equivalent). Onboarding gates the shell on
//  first launch; after finishing, the neighbor lands on Discover.
//

import SwiftUI

struct RootView: View {
    @State private var onboarded = RootView.launchOnboarded
    @State private var tab: AppTab = RootView.launchTab

    /// QA hook: `SIMCTL_CHILD_BOOTSTRAP=home xcrun simctl launch …` skips
    /// onboarding and opens straight to a tab. No effect in normal launches.
    private static var bootstrap: String? {
        ProcessInfo.processInfo.environment["BOOTSTRAP"]?.lowercased()
    }
    static var launchOnboarded: Bool { bootstrap != nil }
    static var launchTab: AppTab {
        switch bootstrap {
        case "home":    return .home
        case "shelf":   return .shelf
        case "profile": return .profile
        default:        return .discover
        }
    }

    var body: some View {
        if onboarded {
            MainShell(tab: $tab)
                .transition(.opacity)
        } else {
            OnboardingFlow {
                withAnimation(.easeInOut) { onboarded = true }
            }
        }
    }
}

private struct MainShell: View {
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

#Preview { RootView() }
