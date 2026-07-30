//
//  DataScannerRepresentable.swift
//  BookShare
//
//  SwiftUI bridge for the DataScannerViewController that VisionScannerService
//  owns. Kept intentionally dumb — all behavior lives in the service/view model.
//

import SwiftUI
import VisionKit

struct DataScannerRepresentable: UIViewControllerRepresentable {
    let scannerService: VisionScannerService

    func makeUIViewController(context: Context) -> DataScannerViewController {
        scannerService.scannerViewController ?? scannerService.makeViewController()
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        // No dynamic properties to push down; start/stop is driven explicitly
        // by ScannerViewModel via scannerService.startScanning()/stopScanning().
    }
}
