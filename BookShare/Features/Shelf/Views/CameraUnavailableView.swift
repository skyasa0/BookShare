//
//  CameraUnavailableView.swift
//  BookShare
//
//  Friendly fallback whenever the live scanner can't run: permission denied,
//  restricted, or no camera hardware (Simulator). Always offers manual entry
//  as the escape hatch. Reskinned to the BookShare design system — this is the
//  screen shown in the Simulator, so it's fully paper-styled.
//

import SwiftUI

struct CameraUnavailableView: View {
    let availability: CameraAvailability
    var onOpenSettings: () -> Void
    var onManualEntry: () -> Void

    var body: some View {
        VStack(spacing: BSSpace.l) {
            Spacer()
            Image(systemName: iconName)
                .font(.system(size: 42))
                .foregroundStyle(BSColor.rust)

            VStack(spacing: BSSpace.s) {
                Text(title).font(BSFont.display).foregroundStyle(BSColor.ink)
                    .multilineTextAlignment(.center)
                Text(message).font(BSFont.body).foregroundStyle(BSColor.muted)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, BSSpace.l)

            Spacer()

            VStack(spacing: BSSpace.s) {
                BSButton(title: "Enter ISBN manually", icon: "keyboard", action: onManualEntry)
                if showsSettingsButton {
                    BSButton(title: "Open Settings", style: .ghost, action: onOpenSettings)
                }
            }
        }
        .padding(.horizontal, BSSpace.xl)
        .padding(.vertical, BSSpace.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .bsScreen()
        .accessibilityElement(children: .contain)
    }

    private var iconName: String {
        switch availability {
        case .denied, .restricted: "camera.badge.ellipsis"
        case .unavailableOnDevice: "camera.metering.unknown"
        default: "camera"
        }
    }
    private var title: String {
        switch availability {
        case .denied: "Camera access needed"
        case .restricted: "Camera restricted"
        case .unavailableOnDevice: "No camera here"
        default: "Camera not ready"
        }
    }
    private var message: String {
        switch availability {
        case .denied:
            "BookShare scans barcodes to fill in a book's details. Enable the camera in Settings, or enter the ISBN yourself."
        case .restricted:
            "Camera access is restricted on this device. You can still list a book by entering its ISBN."
        case .unavailableOnDevice:
            "The Simulator has no camera. Enter an ISBN and we'll fetch the rest — on a real device this opens straight to the scanner."
        default:
            "Enter the ISBN and we'll do the rest."
        }
    }
    private var showsSettingsButton: Bool { availability == .denied }
}

#Preview {
    CameraUnavailableView(availability: .unavailableOnDevice, onOpenSettings: {}, onManualEntry: {})
}
