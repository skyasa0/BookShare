//
//  WhatsApp.swift
//  BookShare
//
//  Optional handoff escape hatch: deep-link into WhatsApp with a prefilled
//  message. Only ever used after a loan is accepted (numbers are never shared
//  before that). The in-app handoff (spot + time) is the primary path.
//

import UIKit

enum WhatsApp {
    /// Opens WhatsApp to `phone` with `message` prefilled. Returns false if the
    /// number is unusable or WhatsApp can't be opened.
    @discardableResult
    static func open(phone: String, message: String) -> Bool {
        let digits = phone.filter(\.isNumber)   // wa.me wants digits only, incl. country code
        guard !digits.isEmpty else { return false }
        let text = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://wa.me/\(digits)?text=\(text)") else { return false }
        UIApplication.shared.open(url)
        return true
    }

    /// Suggested opener message for a book handoff.
    static func handoffMessage(book: String, isLender: Bool) -> String {
        isLender
            ? "Hi! It's about \"\(book)\" on BookShare — when works for the handoff?"
            : "Hi! Thanks for lending \"\(book)\" on BookShare — when works for the handoff?"
    }
}
