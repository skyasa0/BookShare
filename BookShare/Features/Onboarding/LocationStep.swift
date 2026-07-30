//
//  LocationStep.swift
//  BookShare
//
//  Shown after authentication when the neighbor has no home location yet
//  (AuthService.State.needsLocation). "Use current location" pulls a one-shot
//  CoreLocation fix; manual entry geocodes a typed address. Either way only a
//  coordinate is sent to update_my_location — the radius filter runs server-side.
//

import SwiftUI
import CoreLocation

struct LocationStep: View {
    @Environment(AuthService.self) private var auth
    @Environment(LocationService.self) private var location

    @State private var address = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                BSStepChip(current: 2, total: 2)
            }
            .padding(.top, BSSpace.s)

            Text("Where do you live?")
                .font(BSFont.display)
                .foregroundStyle(BSColor.ink)
                .padding(.top, BSSpace.l)
                .padding(.bottom, BSSpace.xl)

            VStack(alignment: .leading, spacing: BSSpace.l) {
                Text("We use your location to find books nearby. Your exact address is never shown to other users.")
                    .font(BSFont.body)
                    .foregroundStyle(BSColor.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                BSButton(title: "Use current location", icon: "location.fill",
                         style: .ghost, isLoading: busy) { useCurrentLocation() }

                HStack {
                    Rectangle().fill(BSColor.line).frame(height: 1)
                    Text("or enter it").font(BSFont.sans(12)).foregroundStyle(BSColor.muted)
                    Rectangle().fill(BSColor.line).frame(height: 1)
                }.padding(.vertical, 4)

                BSField(label: "Home address", placeholder: "Street, city", text: $address)

                if let error { InlineBanner(text: error, tone: .attention) }

                PrivacyNote("Neighbors only ever see an approximate distance — like “0.3 mi” — computed on our servers.")
            }

            Spacer()
            BSButton(title: "Finish setup", isLoading: busy) { useTypedAddress() }
            Button("Sign out") { Task { await auth.signOut() } }
                .font(BSFont.sans(13, .semibold))
                .foregroundStyle(BSColor.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, BSSpace.xs)
        }
        .padding(.horizontal, BSSpace.xl)
        .padding(.bottom, BSSpace.xl)
        .bsScreen()
    }

    private func useCurrentLocation() {
        busy = true; error = nil
        Task {
            do {
                let coord = try await location.currentLocation()
                try await auth.setHomeLocation(lat: coord.latitude, lng: coord.longitude)
                // state → .ready; RootView swaps to the tabs.
            } catch {
                self.error = (error as? LocationService.LocationError)?.errorDescription
                    ?? error.localizedDescription
            }
            busy = false
        }
    }

    private func useTypedAddress() {
        guard !address.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Enter an address, or tap “Use current location.”"; return
        }
        busy = true; error = nil
        Task {
            do {
                let placemarks = try await CLGeocoder().geocodeAddressString(address)
                guard let coord = placemarks.first?.location?.coordinate else {
                    throw LocationService.LocationError.unavailable
                }
                try await auth.setHomeLocation(lat: coord.latitude, lng: coord.longitude)
            } catch {
                self.error = "We couldn't find that address. Try adding a city, or use current location."
            }
            busy = false
        }
    }
}
