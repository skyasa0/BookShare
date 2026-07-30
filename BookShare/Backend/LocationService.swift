//
//  LocationService.swift
//  BookShare
//
//  Thin CoreLocation wrapper: request when-in-use permission and fetch a single
//  fix. The device only ever sends its coordinate to `update_my_location`; the
//  radius filter itself runs server-side in PostGIS.
//

import Foundation
import CoreLocation

@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {

    private(set) var authorization: CLAuthorizationStatus
    private let manager = CLLocationManager()
    private var fixContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    /// True while we're waiting for the permission prompt to resolve before
    /// asking for a fix (avoids requesting a location before it's authorized).
    private var awaitingAuthThenFix = false

    enum LocationError: LocalizedError {
        case denied, unavailable
        var errorDescription: String? {
            switch self {
            case .denied:      return "Location access is off. You can enter your address instead, or enable it in Settings."
            case .unavailable: return "Couldn't get a location fix. Try again or enter your address."
            }
        }
    }

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Request permission (if needed) and return a single coordinate fix.
    func currentLocation() async throws -> CLLocationCoordinate2D {
        if authorization == .denied || authorization == .restricted {
            throw LocationError.denied
        }
        return try await withCheckedThrowingContinuation { cont in
            self.fixContinuation = cont
            if self.authorization == .notDetermined {
                // Wait for the prompt to resolve; requestLocation() happens once
                // authorization is granted (see delegate below).
                self.awaitingAuthThenFix = true
                self.manager.requestWhenInUseAuthorization()
            } else {
                self.manager.requestLocation()
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        guard awaitingAuthThenFix else { return }
        switch authorization {
        case .authorizedWhenInUse, .authorizedAlways:
            awaitingAuthThenFix = false
            manager.requestLocation()               // now safe to ask for a fix
        case .denied, .restricted:
            awaitingAuthThenFix = false
            fixContinuation?.resume(throwing: LocationError.denied)
            fixContinuation = nil
        case .notDetermined:
            break                                    // prompt still open
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coord = locations.first?.coordinate else {
            fixContinuation?.resume(throwing: LocationError.unavailable)
            fixContinuation = nil
            return
        }
        fixContinuation?.resume(returning: coord)
        fixContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        fixContinuation?.resume(throwing: error)
        fixContinuation = nil
    }
}
