//
//  ScannerViewModel.swift
//  BookShare
//
//  Owns the scanner's state machine end to end: permission -> live detection
//  -> stability tracking -> validation -> capture. `BookMetadataViewModel`
//  takes over once a valid ISBN is captured.
//

import Foundation
import Combine
import UIKit

@MainActor
@Observable
final class ScannerViewModel {

    enum ScanState: Equatable {
        case requestingPermission
        case permissionDenied(CameraAvailability)
        case scanning
        case detecting(BarcodeResult)   // tracking, not yet stable
        case captured(ISBN)             // stable + validated, handing off
        case error(ScanErrorReason)
    }

    enum ScanErrorReason: Equatable {
        case invalidISBN
        case barcodeTooSmall
        case multipleBarcodes
        case lowLight

        var title: String {
            switch self {
            case .invalidISBN: "That doesn't look like a valid ISBN"
            case .barcodeTooSmall: "Barcode too small"
            case .multipleBarcodes: "Multiple barcodes detected"
            case .lowLight: "It's a little dark"
            }
        }

        var message: String {
            switch self {
            case .invalidISBN: "The scanned code failed checksum validation. Try again, or enter the ISBN manually."
            case .barcodeTooSmall: "Move a little closer to the barcode."
            case .multipleBarcodes: "Center just one barcode inside the frame."
            case .lowLight: "Turn on the flash for a better read."
            }
        }
    }

    private(set) var state: ScanState = .requestingPermission
    private(set) var liveOutline: BarcodeResult?
    var isTorchOn = false

    let permissionService: CameraPermissionService
    let scannerService: VisionScannerService

    private var cancellables = Set<AnyCancellable>()
    private var lastPayload: String?
    private var stabilityStreak = 0
    private var lastReadAt: Date?
    private var recentlyCapturedISBNs: [String: Date] = [:]

    init(
        permissionService: CameraPermissionService? = nil,
        scannerService: VisionScannerService? = nil
    ) {
        self.permissionService = permissionService ?? CameraPermissionService()
        self.scannerService = scannerService ?? VisionScannerService()
        observeDetections()
    }

    // MARK: - Lifecycle

    func onAppear() {
        Task { await requestPermissionAndStart() }
    }

    func onDisappear() {
        scannerService.stopScanning()
    }

    private func requestPermissionAndStart() async {
        state = .requestingPermission
        let availability = await permissionService.requestAccess()
        switch availability {
        case .available:
            state = .scanning
            scannerService.startScanning()
        case .denied, .restricted, .unavailableOnDevice, .notDetermined:
            state = .permissionDenied(availability)
        }
    }

    // MARK: - Detection handling

    private func observeDetections() {
        scannerService.detectionSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.handle(result)
            }
            .store(in: &cancellables)
    }

    private func handle(_ result: BarcodeResult) {
        let canProcessDetection: Bool
        switch state {
        case .scanning, .detecting: canProcessDetection = true
        default: canProcessDetection = false
        }
        guard canProcessDetection else { return }

        liveOutline = result

        // Reset the stability streak if the payload changed or too much time
        // passed since the last read (the phone moved / a different book).
        let now = result.observedAt
        if result.payload != lastPayload || elapsedTooLong(since: lastReadAt, now: now) {
            lastPayload = result.payload
            stabilityStreak = 1
        } else {
            stabilityStreak += 1
        }
        lastReadAt = now

        state = .detecting(result)
        Haptics.selectionTick()

        guard stabilityStreak >= ScannerConstants.stabilityReadCount else { return }

        capture(result)
    }

    private func elapsedTooLong(since last: Date?, now: Date) -> Bool {
        guard let last else { return false }
        return now.timeIntervalSince(last) > ScannerConstants.stabilityWindow
    }

    private func capture(_ result: BarcodeResult) {
        guard let isbn = ISBN(raw: result.payload) else {
            fail(.invalidISBN)
            return
        }

        // Ignore a duplicate capture of the same book scanned moments ago —
        // e.g. the user's hand is still steady right after a successful scan.
        if let last = recentlyCapturedISBNs[isbn.isbn13],
           Date().timeIntervalSince(last) < ScannerConstants.duplicateScanCooldown {
            return
        }

        recentlyCapturedISBNs[isbn.isbn13] = Date()
        stabilityStreak = 0
        scannerService.stopScanning()
        Haptics.success()
        state = .captured(isbn)
    }

    private func fail(_ reason: ScanErrorReason) {
        stabilityStreak = 0
        Haptics.error()
        state = .error(reason)
    }

    // MARK: - Controls

    func retry() {
        lastPayload = nil
        stabilityStreak = 0
        liveOutline = nil
        state = .scanning
        scannerService.startScanning()
    }

    func toggleTorch() {
        isTorchOn.toggle()
        scannerService.setTorch(on: isTorchOn)
    }

    func requestOpenSettings() {
        permissionService.openSystemSettings()
    }

    /// Entry point for the photo-library and manual-entry paths, which skip
    /// the live camera stability loop and validate/capture immediately.
    func captureManual(rawISBN: String) -> Bool {
        guard let isbn = ISBN(raw: rawISBN) else {
            fail(.invalidISBN)
            return false
        }
        Haptics.success()
        state = .captured(isbn)
        return true
    }
}
