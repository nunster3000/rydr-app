//
//  LocationManagerView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 7/27/25.
//


import SwiftUI
import MapKit

struct LocationManagerView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    var body: some View {
        VStack {
            if let location = locationManager.currentLocation {
                Map(position: .constant(.region(region))) {
                    UserAnnotation()
                }
                .mapControls {
                    MapUserLocationButton()
                }
                .onAppear {
                    region.center = location.coordinate
                }
                .frame(height: 300)
                .cornerRadius(12)
                .padding()
                
                Text("Latitude: \(location.coordinate.latitude)")
                Text("Longitude: \(location.coordinate.longitude)")
            } else {
                Text("Requesting location...")
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .onAppear {
            locationManager.requestLocation()
        }
        .navigationTitle("Your Location")
    }
}

#Preview {
    LocationManagerView()
}

