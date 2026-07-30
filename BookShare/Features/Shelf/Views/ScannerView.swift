//
//  ScannerView.swift
//  BookShare
//
//  Entry point for BR-01 ("scan an ISBN, list a book in under a minute").
//  Opens straight to a live scanner (device), auto-captures on a stable read,
//  then flows loading -> found -> AddBookView. On the Simulator (no camera) it
//  opens to CameraUnavailableView with manual entry / photo import as peers.
//

import SwiftUI
import PhotosUI

struct ScannerView: View {
    /// Called after a book is listed, so the Shelf can dismiss + refresh.
    var onPublished: () -> Void = {}

    @State private var scannerVM = ScannerViewModel()
    @State private var metadataVM = BookMetadataViewModel()

    @State private var showManualEntry = false
    @State private var showHelp = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var photoScanError: PhotoLibraryBarcodeScanner.ScanError?
    @State private var isProcessingPhoto = false

    @State private var draft: BookDraft?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                cameraLayer

                VStack {
                    topBar
                    Spacer()
                    switch scannerVM.state {
                    case .scanning, .detecting: controlsLayer
                    default: EmptyView()
                    }
                }

                stateOverlay
            }
            .statusBarHidden()
            .navigationBarBackButtonHidden(true)
            .onAppear { scannerVM.onAppear() }
            .onDisappear { scannerVM.onDisappear() }
            .sheet(isPresented: $showManualEntry) {
                ManualISBNEntryView { raw in _ = scannerVM.captureManual(rawISBN: raw) }
            }
            .sheet(isPresented: $showHelp) {
                ScannerHelpSheet().presentationDetents([.medium])
            }
            .photosPicker(isPresented: photoPickerBinding, selection: $photoPickerItem, matching: .images)
            .onChange(of: photoPickerItem) { _, newItem in handlePhotoPicked(newItem) }
            .onChange(of: scannerVM.state) { _, newState in
                if case .captured(let isbn) = newState { metadataVM.fetch(isbn: isbn) }
            }
            .navigationDestination(item: $draft) { d in
                AddBookView(draft: d, onPublished: onPublished)
            }
        }
        .tint(BSColor.rust)
    }

    // MARK: - Layers

    @ViewBuilder
    private var cameraLayer: some View {
        switch scannerVM.permissionService.availability {
        case .available:
            DataScannerRepresentable(scannerService: scannerVM.scannerService)
                .ignoresSafeArea()
                .overlay {
                    switch scannerVM.state {
                    case .detecting(let result): ScannerOverlay(liveDetection: result, isStable: isStable)
                    default:                      ScannerOverlay(liveDetection: nil, isStable: false)
                    }
                }
        default:
            CameraUnavailableView(
                availability: scannerVM.permissionService.availability,
                onOpenSettings: scannerVM.requestOpenSettings,
                onManualEntry: { showManualEntry = true }
            )
        }
    }

    private var isStable: Bool {
        if case .captured = scannerVM.state { return true }
        return false
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.15), in: Circle())
            }
            .accessibilityLabel("Close scanner")
            Spacer()
        }
        .overlay(
            VStack(spacing: 2) {
                Text("Scan a book").font(BSFont.serif(17, .bold))
                Text("Center the barcode inside the frame")
                    .font(BSFont.sans(12)).foregroundStyle(.white.opacity(0.7))
            }
            .foregroundStyle(.white)
        )
        .padding(.horizontal, BSSpace.l)
        .padding(.top, BSSpace.s)
        // Hide the dark-camera chrome text when the paper fallback is showing.
        .opacity(scannerVM.permissionService.availability == .available ? 1 : 0)
    }

    private var controlsLayer: some View {
        ScannerControls(
            isTorchOn: scannerVM.isTorchOn,
            onToggleTorch: scannerVM.toggleTorch,
            onManualEntry: { showManualEntry = true },
            onPhotoLibrary: { photoPickerItem = nil; showPhotoPicker() },
            onHelp: { showHelp = true }
        )
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch scannerVM.state {
        case .error(let reason):
            ScannerErrorBanner(reason: reason, onRetry: scannerVM.retry)
        case .captured(let isbn):
            metadataOverlay(for: isbn)
        default:
            EmptyView()
        }

        if isProcessingPhoto { LoadingView(isbn: placeholderISBN) }
        if let photoScanError { photoErrorBanner(photoScanError) }
    }

    @ViewBuilder
    private func metadataOverlay(for isbn: ISBN) -> some View {
        switch metadataVM.fetchState {
        case .idle, .loading:
            LoadingView(isbn: isbn)
        case .found(let metadata):
            BookFoundView(metadata: metadata) {
                draft = BookDraft.prefilled(from: metadata, isbn: isbn)
            }
        case .notFound(let isbn):
            BookFetchErrorView(
                kind: .notFound(isbn),
                onRetry: { metadataVM.fetch(isbn: isbn) },
                onEnterManually: { showManualEntry = true },
                onAddWithoutMetadata: { draft = BookDraft(isbn: isbn) }
            )
        case .offline(let isbn):
            BookFetchErrorView(
                kind: .offline(isbn),
                onRetry: { metadataVM.fetch(isbn: isbn) },
                onEnterManually: { showManualEntry = true },
                onAddWithoutMetadata: { draft = BookDraft(isbn: isbn) }
            )
        }
    }

    private func photoErrorBanner(_ error: PhotoLibraryBarcodeScanner.ScanError) -> some View {
        let reason: ScannerViewModel.ScanErrorReason = switch error {
        case .noBarcodeFound: .invalidISBN
        case .multipleBarcodesFound: .multipleBarcodes
        case .imageUnreadable: .barcodeTooSmall
        }
        return ScannerErrorBanner(reason: reason) { photoScanError = nil }
    }

    // MARK: - Photo library

    private var photoPickerBinding: Binding<Bool> {
        Binding(get: { photoPickerItem != nil }, set: { if !$0 { photoPickerItem = nil } })
    }

    private func showPhotoPicker() { /* presentation driven by photoPickerBinding */ }

    private func handlePhotoPicked(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            isProcessingPhoto = true
            defer { isProcessingPhoto = false }
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                let result = try await PhotoLibraryBarcodeScanner.scan(image)
                if scannerVM.captureManual(rawISBN: result.payload) { photoScanError = nil }
            } catch let error as PhotoLibraryBarcodeScanner.ScanError {
                photoScanError = error
            } catch {
                photoScanError = .imageUnreadable
            }
        }
    }

    private var placeholderISBN: ISBN { ISBN(raw: "9780000000002")! }
}

#Preview { ScannerView() }
