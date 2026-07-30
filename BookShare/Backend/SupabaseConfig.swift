//
//  SupabaseConfig.swift
//  BookShare
//
//  Connection settings for the backend. Values below target the LOCAL Supabase
//  stack (`supabase start`). The anon key is a public, publishable key — safe to
//  embed in the client (it only grants access allowed by RLS). For a hosted
//  project, swap `url`/`anonKey` for your project's values (see SETUP.md).
//

import Foundation

enum SupabaseConfig {
    /// Local Supabase API gateway. The iOS Simulator shares the host network,
    /// so 127.0.0.1 reaches the stack directly.
    static let url = URL(string: "http://127.0.0.1:54321")!

    /// Local-dev anon key (identical across all local Supabase installs; public).
    static let anonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" +
        ".eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9" +
        ".CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"

    /// OAuth / password-reset deep-link target (registered in Info.plist +
    /// supabase/config.toml `additional_redirect_urls`).
    static let redirectURL = URL(string: "bookshare://auth-callback")!
}
