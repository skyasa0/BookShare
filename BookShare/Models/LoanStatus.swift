//
//  LoanStatus.swift
//  BookShare
//
//  The global status vocabulary (Deliverable 14 §05). One vocabulary,
//  learned once — the same words appear on Discover badges, the Home queue,
//  and the loan stepper. Never introduce status words outside this set.
//

import SwiftUI

enum LoanStatus: String, CaseIterable, Identifiable {
    case available = "Available"   // listed and free to request
    case requested = "Requested"   // borrow request pending, 48h window
    case accepted  = "Accepted"    // lender said yes; handoff being planned
    case onLoan    = "On loan"     // handoff confirmed; due date running
    case returned  = "Returned"    // lender confirmed return; ratings triggered

    var id: String { rawValue }

    /// Map from the Postgres `loan_status` enum values (snake_case).
    init?(dbValue: String) {
        switch dbValue {
        case "available": self = .available
        case "requested": self = .requested
        case "accepted":  self = .accepted
        case "on_loan":   self = .onLoan
        case "returned":  self = .returned
        default:          return nil
        }
    }

    /// Postgres `loan_status` value for this case.
    var dbValue: String {
        switch self {
        case .available: return "available"
        case .requested: return "requested"
        case .accepted:  return "accepted"
        case .onLoan:    return "on_loan"
        case .returned:  return "returned"
        }
    }

    /// Visual tone: sage = actionable-positive, neutral = passive,
    /// terracotta tint = needs attention.
    enum Tone { case positive, passive, attention }

    var tone: Tone {
        switch self {
        case .available, .returned: return .positive
        case .requested, .accepted: return .attention
        case .onLoan:               return .passive
        }
    }

    var background: Color {
        switch tone {
        case .positive:  return BSColor.sageBg
        case .passive:   return BSColor.neutralBg
        case .attention: return BSColor.rustSoft
        }
    }

    var foreground: Color {
        switch tone {
        case .positive:  return BSColor.sage
        case .passive:   return BSColor.muted
        case .attention: return BSColor.rustDeep
        }
    }

    /// Loan lifecycle order for the 4-node stepper (Available is a listing
    /// state, not a lifecycle node).
    static let lifecycle: [LoanStatus] = [.requested, .accepted, .onLoan, .returned]
}
