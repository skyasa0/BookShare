//
//  PhotoLibraryBarcodeScanner.swift
//  BookShare
//
//  Runs the same barcode symbologies through plain Vision (VNDetectBarcodesRequest)
//  against a still image, for the "scan from a photo you already have" path
//  (e.g. a screenshot of a bookstore listing, or a photo taken earlier).
//

import Vision
import UIKit

enum PhotoLibraryBarcodeScanner {

    enum ScanError: Error {
        case noBarcodeFound
        case multipleBarcodesFound([BarcodeResult])
        case imageUnreadable
    }

    /// Runs on a background thread; safe to call from an async context directly.
    static func scan(_ image: UIImage) async throws -> BarcodeResult {
        guard let cgImage = image.cgImage else { throw ScanError.imageUnreadable }

        let request = VNDetectBarcodesRequest()
        request.symbologies = [.ean13, .ean8, .upce]

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgImagePropertyOrientation)
        try handler.perform([request])

        let results: [BarcodeResult] = (request.results ?? []).compactMap { observation in
            guard let payload = observation.payloadStringValue else { return nil }
            let symbology: BarcodeSymbology = switch observation.symbology {
            case .ean13: .ean13
            case .ean8: .ean8
            case .upce: .upce
            default: .unknown
            }
            return BarcodeResult(
                payload: payload,
                symbology: symbology,
                boundingBox: observation.boundingBox,
                observedAt: Date()
            )
        }

        // Prefer a Bookland (978/979) EAN-13 if multiple codes are in frame —
        // e.g. a photo of a book showing both the ISBN and a price barcode.
        if let isbnCandidate = results.first(where: \.isBooklandCandidate)  {
            return isbnCandidate
        }

        switch results.count {
        case 0: throw ScanError.noBarcodeFound
        case 1: return results[0]
        default: throw ScanError.multipleBarcodesFound(results)
        }
    }
}

private extension UIImage {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}
