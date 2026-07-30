//
//  BookShareApp.swift
//  BookShare
//
//  Created by Srijan Kyasa on 7/20/26.
//
//  App entry. Owns the shared AuthService + LocationService and injects them
//  into the environment. Backend is the local Supabase stack (see SETUP.md).
//

import SwiftUI

@main
struct BookShareApp: App {
    @State private var auth = AuthService()
    @State private var location = LocationService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(location)
        }
    }
}
