//
//  ScannerConstants.swift
//  BookShare
//

import Foundation
import CoreGraphics

enum ScannerConstants {
    /// Number of consecutive identical reads required before we treat a
    /// barcode as "stable" and auto-capture, rather than a single noisy frame.
    static let stabilityReadCount = 3

    /// Window within which repeated reads count toward stability; if the gap
    /// between reads exceeds this, the streak resets.
    static let stabilityWindow: TimeInterval = 0.6

    /// Minimum time between two *different* successful captures, so a user
    /// re-opening the scanner immediately after a scan doesn't double-fire.
    static let recaptureThrottle: TimeInterval = 1.5

    /// Cooldown before the same ISBN can be re-scanned again in one session
    /// (protects against the scanner re-detecting the same book repeatedly
    /// while the user is still holding the phone steady after a capture).
    static let duplicateScanCooldown: TimeInterval = 4.0

    static let scanFrameSize = CGSize(width: 280, height: 180)
    static let cornerBracketLength: CGFloat = 28
    static let cornerBracketLineWidth: CGFloat = 4

    static let scanLineDuration: TimeInterval = 1.8
}
