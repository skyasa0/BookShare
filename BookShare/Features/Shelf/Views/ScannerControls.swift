//
//  ScannerControls.swift
//  BookShare
//
//  Bottom action row over the live camera: flash, manual entry, photo import,
//  help. No shutter button — capture is fully automatic. Kept dark (it sits on
//  the camera feed); active state uses the terracotta accent.
//

import SwiftUI

struct ScannerControls: View {
    let isTorchOn: Bool
    let onToggleTorch: () -> Void
    let onManualEntry: () -> Void
    let onPhotoLibrary: () -> Void
    let onHelp: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            controlButton(systemImage: isTorchOn ? "bolt.fill" : "bolt.slash",
                          label: "Flash", isActive: isTorchOn, action: onToggleTorch)
                .accessibilityLabel(isTorchOn ? "Turn flash off" : "Turn flash on")
            controlButton(systemImage: "keyboard", label: "Enter ISBN", action: onManualEntry)
                .accessibilityLabel("Enter ISBN manually")
            controlButton(systemImage: "photo.on.rectangle", label: "Photos", action: onPhotoLibrary)
                .accessibilityLabel("Scan from photo library")
            controlButton(systemImage: "questionmark.circle", label: "Help", action: onHelp)
                .accessibilityLabel("Scanning help")
        }
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private func controlButton(systemImage: String, label: String,
                               isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isActive ? BSColor.onRust : .white)
                    .frame(width: 44, height: 44)
                    .background(isActive ? BSColor.rust : Color.white.opacity(0.14), in: Circle())
                Text(label).font(BSFont.sans(11, .medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.black
        ScannerControls(isTorchOn: false, onToggleTorch: {}, onManualEntry: {},
                        onPhotoLibrary: {}, onHelp: {})
    }
}
