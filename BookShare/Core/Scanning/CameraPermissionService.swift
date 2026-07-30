//
//  CameraPermissionService.swift
//  BookShare
//
//  Single source of truth for "can we show the scanner right now?". Keeps
//  AVFoundation's AVAuthorizationStatus out of the view layer entirely.
//

import AVFoundation
import Foundation
import VisionKit
import UIKit

enum CameraAvailability: Equatable {
    case available
    case denied
    case restricted
    case unavailableOnDevice   // simulator, or no camera hardware
    case notDetermined
}

@MainActor
@Observable
final class CameraPermissionService {

    private(set) var availability: CameraAvailability = .notDetermined

    init() {
        refresh()
    }

    func refresh() {
        guard DataScannerViewController.isSupported, DataScannerViewController.isAvailable else {
            // isSupported is false on Simulator and on devices without the
            // required hardware; isAvailable is false if another app/process
            // currently owns the camera.
            availability = .unavailableOnDevice
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            availability = .available
        case .denied:
            availability = .denied
        case .restricted:
            availability = .restricted
        case .notDetermined:
            availability = .notDetermined
        @unknown default:
            availability = .notDetermined
        }
    }

    /// Requests the system permission dialog. Only actually prompts if the
    /// current status is `.notDetermined`; otherwise it's a no-op that just
    /// re-reads the current status.
    @discardableResult
    func requestAccess() async -> CameraAvailability {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            availability = granted ? .available : .denied
        } else {
            refresh()
        }
        return availability
    }

    /// Deep-links to Settings for the denied/restricted friendly UI's "Open Settings" button.
    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
