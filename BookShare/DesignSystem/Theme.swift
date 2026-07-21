//
//  Theme.swift
//  BookShare
//
//  The coded twin of Deliverable 14 (Design System).
//  A product about physical books should feel like paper, ink, and shelves.
//
//  NOTE ON FONTS: The design system calls for Lora (serif), DM Sans (sans),
//  and IBM Plex Mono (mono). Those .ttf files are not bundled, so this maps
//  them to the closest system font *designs* — .serif (New York),
//  .default (SF), and .monospaced (SF Mono). To ship the exact type, add the
//  font files to the target + Info.plist and swap the `Font` factory below.
//

import SwiftUI

// MARK: - Color tokens

extension Color {
    /// Hex initializer, e.g. Color(hex: "A8431F").
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: UInt64
        switch s.count {
        case 8: (a, r, g, b) = (v >> 24 & 0xFF, v >> 16 & 0xFF, v >> 8 & 0xFF, v & 0xFF)
        default: (a, r, g, b) = (255, v >> 16 & 0xFF, v >> 8 & 0xFF, v & 0xFF)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

/// Design System color palette — one accent (terracotta rust) carries every
/// primary action and never decorates.
enum BSColor {
    static let paper      = Color(hex: "F4EFE4") // app background, all screens
    static let card       = Color(hex: "FBF7EE") // cards, sheets, tab bar
    static let field      = Color(hex: "EBE3CF") // inputs, secondary buttons
    static let fieldLine  = Color(hex: "D9CDB2")
    static let ink        = Color(hex: "221812") // primary text, icons
    static let muted      = Color(hex: "6F6152") // secondary text, metadata
    static let line       = Color(hex: "E0D6C1") // hairline separators

    static let rust       = Color(hex: "A8431F") // primary actions, links, active tab, authors
    static let rustDeep   = Color(hex: "8A3617") // pressed / hover
    static let rustSoft   = Color(hex: "F0DFD2") // "needs attention" tint

    static let sageBg     = Color(hex: "E4E8D5") // positive status bg
    static let sage       = Color(hex: "55663F") // positive status ink
    static let neutralBg  = Color(hex: "E7E0D0") // passive status bg
    static let gold       = Color(hex: "C9973C") // rating stars, avatars — never buttons

    static let onRust     = Color(hex: "FBF7EE") // cream text on terracotta
    static let placeholder = Color(hex: "8B7B63") // field placeholder ink
    static let labelInk   = Color(hex: "7A6C58")  // uppercase field labels
}

// MARK: - Typography

/// Three faces, three jobs. Lora is the voice (titles), DM Sans is the
/// interface, IBM Plex Mono marks data (distances, dates, counts).
enum BSFont {
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // Named scale from Deliverable 14 §02
    static let display   = serif(30, .bold)   // "Where do you live?"
    static let title     = serif(26, .bold)   // "Discover"
    static let cardTitle = serif(15.5, .bold) // book titles
    static let body      = sans(14.5, .regular)
    static let button    = sans(16, .bold)
    static let data      = mono(12, .semibold) // distances, dates, steps
}

// MARK: - Spacing (4-pt grid)

enum BSSpace {
    static let xs: CGFloat = 4   // icon gaps
    static let s: CGFloat = 8    // chip gaps, meta rows
    static let m: CGFloat = 12   // card gaps, list padding
    static let l: CGFloat = 16   // card padding
    static let xl: CGFloat = 26  // screen gutters
}

// MARK: - Radius

enum BSRadius {
    static let s: CGFloat = 8    // covers, map chips
    static let m: CGFloat = 15   // fields, cards, buttons
    static let pill: CGFloat = 100 // chips, badges, steps
}

// MARK: - Reusable modifiers

extension View {
    /// Standard screen background + horizontal gutter.
    func bsScreen() -> some View {
        self.background(BSColor.paper.ignoresSafeArea())
    }

    /// Uppercase, tracked field label (DM Sans 700, 11px).
    func bsFieldLabel() -> some View {
        self.font(BSFont.sans(11, .bold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(BSColor.labelInk)
    }
}
