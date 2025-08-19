//
//  RideInProgressView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/21/25.
//
import SwiftUI
import MapKit
import FirebaseFirestore

struct RideInProgressView: View {
    var driver: Driver
    @State private var route: MKRoute?
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.6407, longitude: -84.4277),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    
    @State private var showChat = false
    @State private var etaDate: Date?

    var body: some View {
        ZStack {
            // Map with live route
            Map(position: $cameraPosition) {
                UserAnnotation()
                if let route = route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 5)
                }
            }
            .mapControls { MapUserLocationButton() }
            .ignoresSafeArea()

            VStack(spacing: 16) {
                driverInfoPanel

                HStack(spacing: 16) {
                    Button(action: { showChat.toggle() }) {
                        Label("Message", systemImage: "message.fill")
                    }

                    Button(action: {
                        print("Calling driver...")
                    }) {
                        Label("Call", systemImage: "phone.fill")
                    }

                    Button(role: .destructive, action: {
                        print("Cancel ride")
                    }) {
                        Label("Cancel", systemImage: "xmark.circle.fill")
                    }
                }
                .padding()
                .background(Color.white.opacity(0.95))
                .cornerRadius(12)
                .shadow(radius: 4)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 50)

            if showChat {
                ChatOverlay(driver: driver, onClose: { showChat = false })
                    .transition(.move(edge: .bottom))
            }
        }
        .onAppear {
            fetchRouteToDriver()
        }
    }

    var driverInfoPanel: some View {
        HStack(spacing: 16) {
            Image(driver.profileImage)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Your driver: \(driver.name)")
                    .font(.headline)

                if let eta = etaDate {
                    Text("ETA: \(formattedTime(from: eta))")
                        .font(.subheadline)
                } else {
                    Text("Calculating ETA...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                HStack(spacing: 4) {
                    ForEach(0..<5) { i in
                        Image(systemName: i < Int(driver.rating) ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.95))
        .cornerRadius(12)
        .shadow(radius: 4)
        .padding(.horizontal)
    }

    private func fetchRouteToDriver() {
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = MKMapItem(
            placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 33.6450, longitude: -84.4272)) // Mock driver location
        )
        request.transportType = .automobile

        MKDirections(request: request).calculate { response, error in
            if let route = response?.routes.first {
                self.route = route
                self.cameraPosition = .region(route.polyline.boundingMapRect.toRegion())
                self.etaDate = Calendar.current.date(byAdding: .second, value: Int(route.expectedTravelTime), to: Date())
            }
        }
    }

    private func formattedTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Chat Overlay
struct ChatOverlay: View {
    var driver: Driver
    var onClose: () -> Void
    @State private var messageText = ""
    @State private var messages: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Chat with \(driver.name)")
                    .font(.headline)
                Spacer()
                Button("Close", action: onClose)
            }
            .padding()
            .background(Color.white)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(messages, id: \.self) { msg in
                        Text(msg)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }

            HStack {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Send") {
                    sendMessage()
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding()
    }

    private func sendMessage() {
        messages.append("You: \(messageText)")
        messageText = ""
    }
}

extension MKMapRect {
    func toRegion() -> MKCoordinateRegion {
        let center = CLLocationCoordinate2D(
            latitude: origin.y + size.height / 2,
            longitude: origin.x + size.width / 2
        )
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
    }
}

