//
//  LocationManager.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 7/27/25.
import CoreLocation
import MapKit

final class LocationManager: NSObject, ObservableObject {
    @Published var authorization: CLAuthorizationStatus = .notDetermined
    @Published var lastLocation: CLLocation?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
    }

    /// Ask for permission / start updates only when needed.
    func requestIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    /// One-tap recenter helper for a bound region.
    func recenter(_ region: inout MKCoordinateRegion,
                  span: MKCoordinateSpan = .init(latitudeDelta: 0.15, longitudeDelta: 0.15)) {
        guard let c = lastLocation?.coordinate else { return }
        region = MKCoordinateRegion(center: c, span: span)
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("CL error:", error.localizedDescription)
    }
}




