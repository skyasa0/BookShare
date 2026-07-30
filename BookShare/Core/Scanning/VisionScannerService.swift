//
//  VisionScannerService.swift
//  BookShare
//
//  Thin, testable wrapper around VisionKit's DataScannerViewController.
//  Publishes decoded barcodes as `BarcodeResult` and nothing else — no
//  CMSampleBuffers, no UIImages, no camera frames ever leave this type,
//  satisfying the "never store camera frames" requirement by construction.
//

import VisionKit
import Vision
import UIKit
import Combine
import AVFoundation

/// The SwiftUI-facing surface. `ScannerView` wraps `DataScannerRepresentable`,
/// which forwards into this service.
@MainActor
final class VisionScannerService: NSObject, ObservableObject {

    /// Every barcode observed this frame, in the scanner's own coordinate space.
    @Published private(set) var liveDetections: [BarcodeResult] = []

    /// Fires once per "this looks like a real, stable read" — after
    /// `ScannerViewModel` applies its stability window, not raw per-frame noise.
    let detectionSubject = PassthroughSubject<BarcodeResult, Never>()

    private(set) var scannerViewController: DataScannerViewController?
    private var isScanning = false

    static let supportedSymbologies: [VNBarcodeSymbology] = [.ean13, .ean8, .upce]

    func makeViewController() -> DataScannerViewController {
        let recognizedTypes: Set<DataScannerViewController.RecognizedDataType> = [
            .barcode(symbologies: Self.supportedSymbologies)
        ]

        let controller = DataScannerViewController(
            recognizedDataTypes: recognizedTypes,
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: false // we draw our own overlay for full visual control
        )
        controller.delegate = self
        self.scannerViewController = controller
        return controller
    }

    func startScanning() {
        guard !isScanning else { return }
        let controller = scannerViewController ?? makeViewController()
        do {
            try controller.startScanning()
            isScanning = true
        } catch {
            // Surfaced through CameraPermissionService.refresh() by the caller;
            // this failure path is specifically "session couldn't start" (e.g.
            // camera already in use), not a permission issue.
            isScanning = false
        }
    }

    func stopScanning() {
        scannerViewController?.stopScanning()
        isScanning = false
        liveDetections = []
    }

    /// Torch is exposed by the host device's AVCaptureDevice, not directly by
    /// DataScannerViewController, so ScannerControls toggles it through here.
    func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
}

// MARK: - DataScannerViewControllerDelegate

extension VisionScannerService: DataScannerViewControllerDelegate {

    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        publish(allItems)
    }

    func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        publish(allItems)
    }

    func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        publish(allItems)
    }

    func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
        isScanning = false
        liveDetections = []
    }

    private func publish(_ items: [RecognizedItem]) {
        let results: [BarcodeResult] = items.compactMap { item in
            guard case let .barcode(barcode) = item, let payload = barcode.payloadStringValue else { return nil }
            let symbology = mapSymbology(barcode.observation.symbology)
            let box = boundingBox(for: item)
            return BarcodeResult(payload: payload, symbology: symbology, boundingBox: box, observedAt: Date())
        }
        liveDetections = results
        for result in results {
            detectionSubject.send(result)
        }
    }

    private func boundingBox(for item: RecognizedItem) -> CGRect {
        // RecognizedItem.bounds is a quadrilateral (four corner points) in
        // view coordinates; we collapse it to an axis-aligned box for the
        // overlay's outline drawing.
        let points = [item.bounds.topLeft, item.bounds.topRight, item.bounds.bottomLeft, item.bounds.bottomRight]
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
            return .zero
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func mapSymbology(_ symbology: VNBarcodeSymbology) -> BarcodeSymbology {
        switch symbology {
        case .ean13: .ean13
        case .ean8: .ean8
        case .upce: .upce
        default: .unknown
        }
    }
}
