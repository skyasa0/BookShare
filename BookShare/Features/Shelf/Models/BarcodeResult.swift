//
//  BarcodeResult.swift
//  BookShare
//
//  What the scanning layer hands up to the view model. Deliberately does NOT
//  carry any image/pixel data — only the decoded payload and its on-screen
//  bounds, per the "never store camera frames" security requirement.
//

import Foundation
import CoreGraphics

struct BarcodeResult: Identifiable, Equatable {
    let id = UUID()

    /// Raw decoded string, e.g. "9780134685991".
    let payload: String

    /// Symbology as reported by VisionKit/Vision.
    let symbology: BarcodeSymbology

    /// Bounding box in the scanner view's coordinate space, used to draw
    /// the live outline. Not persisted anywhere.
    let boundingBox: CGRect

    /// VisionKit's own confidence/stability signal isn't exposed directly,
    /// so `ScannerViewModel` derives stability from repeated identical reads.
    let observedAt: Date

    var isBooklandCandidate: Bool {
        symbology == .ean13 && ISBNValidator.isBooklandEAN13(payload)
    }
}

enum BarcodeSymbology: String {
    case ean13
    case ean8
    case upce
    case unknown
}
