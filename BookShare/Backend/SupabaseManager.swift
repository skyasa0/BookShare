//
//  SupabaseManager.swift
//  BookShare
//
//  Single shared Supabase client. The Auth module persists the session in the
//  Keychain by default (Del.17's "Keychain storage of the session token"), so
//  sign-in survives relaunches.
//

import Foundation
import Supabase

enum SupabaseManager {
    static let client = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey
    )
}
