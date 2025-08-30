//
//  LocationSearchService.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 8/2/25.
//
// LocationSearchService.swift
import Foundation
import MapKit
import Combine

/// One canonical search completer used across the app.
final class SearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        // Sensible US fallback (Atlanta) so we don't bias to CA on first launch.
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.7490, longitude: -84.3880),
            span: MKCoordinateSpan(latitudeDelta: 0.30, longitudeDelta: 0.30)
        )
    }

    func setQuery(_ text: String) {
        completer.queryFragment = text
    }

    func setRegion(_ region: MKCoordinateRegion) {
        completer.region = region
    }

    // MARK: - MKLocalSearchCompleterDelegate

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async { self.results = completer.results }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async { self.results = [] }
        #if DEBUG
        print("SearchCompleter error:", error.localizedDescription)
        #endif
    }
}


