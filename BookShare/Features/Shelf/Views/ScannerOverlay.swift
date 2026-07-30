//
//  ScannerOverlay.swift
//  BookShare
//
//  Pure presentation: the dimmed mask, rounded frame, corner brackets,
//  animated scan line, and a live outline over whatever barcode the
//  scanner is currently tracking. No scanning logic lives here.
//

import SwiftUI

struct ScannerOverlay: View {
    let liveDetection: BarcodeResult?
    let isStable: Bool

    @State private var scanLineProgress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let frameRect = centeredFrame(in: geometry.size)

            ZStack {
                dimmedMask(fullSize: geometry.size, cutout: frameRect)

                frameOutline(in: frameRect)

                if !reduceMotion {
                    scanLine(in: frameRect)
                }

                if let liveDetection {
                    liveBarcodeOutline(for: liveDetection, containerSize: geometry.size)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { startScanLineAnimation() }
    }

    private func centeredFrame(in size: CGSize) -> CGRect {
        let frameSize = ScannerConstants.scanFrameSize
        let origin = CGPoint(
            x: (size.width - frameSize.width) / 2,
            y: (size.height - frameSize.height) / 2
        )
        return CGRect(origin: origin, size: frameSize)
    }

    /// Blurred/dimmed everywhere except a clear rounded-rect cutout — done
    /// with an even-odd fill rule rather than a real blur for performance,
    /// since this redraws every frame the scan line animates.
    private func dimmedMask(fullSize: CGSize, cutout: CGRect) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: fullSize))
            path.addRoundedRect(in: cutout, cornerSize: CGSize(width: 24, height: 24))
        }
        .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
    }

    private func frameOutline(in rect: CGRect) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)

            cornerBrackets(in: rect)
        }
    }

    private func cornerBrackets(in rect: CGRect) -> some View {
        let length = ScannerConstants.cornerBracketLength
        let lineWidth = ScannerConstants.cornerBracketLineWidth
        let color: Color = isStable ? BSColor.sage : .white

        return ZStack {
            bracket(length: length).stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: length, height: length)
                .position(x: rect.minX + length / 2, y: rect.minY + length / 2)

            bracket(length: length).stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: length, height: length)
                .rotationEffect(.degrees(90))
                .position(x: rect.maxX - length / 2, y: rect.minY + length / 2)

            bracket(length: length).stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: length, height: length)
                .rotationEffect(.degrees(-90))
                .position(x: rect.minX + length / 2, y: rect.maxY - length / 2)

            bracket(length: length).stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: length, height: length)
                .rotationEffect(.degrees(180))
                .position(x: rect.maxX - length / 2, y: rect.maxY - length / 2)
        }
        .animation(.easeOut(duration: 0.2), value: isStable)
    }

    /// A single top-left corner bracket shape; rotated per-corner above.
    private func bracket(length: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: length))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: length, y: 0))
        }
    }

    private func scanLine(in rect: CGRect) -> some View {
        LinearGradient(
            colors: [.clear, BSColor.rust.opacity(0.9), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: rect.width - 16, height: 2)
        .position(
            x: rect.midX,
            y: rect.minY + scanLineProgress * rect.height
        )
        .opacity(isStable ? 0 : 1)
    }

    private func startScanLineAnimation() {
        withAnimation(.easeInOut(duration: ScannerConstants.scanLineDuration).repeatForever(autoreverses: true)) {
            scanLineProgress = 1
        }
    }

    private func liveBarcodeOutline(for detection: BarcodeResult, containerSize: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(isStable ? BSColor.sage : BSColor.gold, lineWidth: 2.5)
            .frame(width: detection.boundingBox.width, height: detection.boundingBox.height)
            .position(x: detection.boundingBox.midX, y: detection.boundingBox.midY)
            .animation(.easeOut(duration: 0.12), value: detection.boundingBox)
    }
}

#Preview {
    ZStack {
        Color.black
        ScannerOverlay(liveDetection: nil, isStable: false)
    }
    .ignoresSafeArea()
}
