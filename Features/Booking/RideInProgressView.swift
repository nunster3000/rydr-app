//
//  RideInProgressView.swift
//  RydrPlayground
//
//  Drop-in replacement.
//  Shows driver tile, live route polyline, actions, payment picker,
//  and presents an EndRideView when the ride completes.
//
import SwiftUI
import MapKit
import _MapKit_SwiftUI

struct RideInProgressView: View {
    @ObservedObject var rideManager: RideManager
    @Environment(\.dismiss) private var dismiss

    @State private var showReportAlert = false
    @State private var showChat = false

    // Map camera binding (required by Map(position:))
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .bottom) {
            map
                .ignoresSafeArea()
            
            panel
        }
        .navigationTitle("Ride in progress")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Close") { dismiss() }
            }
        }
        .sheet(isPresented: $showChat) { ChatSheet() }
        .alert("Report an incident", isPresented: $showReportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Thanks for the report. Our team will review this trip.")
        }
        .onAppear { recenterCamera() }
        .onChange(of: rideManager.liveDriverCoordinate.latitude) { oldLat, newLat in
            recenterCamera()
        }
        .onChange(of: rideManager.liveDriverCoordinate.longitude) { oldLong, newLong in
            recenterCamera()
        }

    }

    // MARK: - Map

    private var map: some View {
        Map(position: $camera) {
            // Current leg polyline (driver→pickup OR pickup→dropoff)
            if let coords = legPolyline {
                MapPolyline(coordinates: coords)
                    // Solid color for widest compatibility. If you target iOS 18,
                    // you can switch to a gradient shape style.
                    .stroke(Color.red.opacity(0.85), lineWidth: 6)
            }

            // Live driver pin
            Annotation("Driver", coordinate: rideManager.liveDriverCoordinate) {
                ZStack {
                    Circle().fill(.thinMaterial).frame(width: 34, height: 34)
                    Image(systemName: "car.fill")
                        .font(.headline)
                }
                .shadow(radius: 2)
            }

            // (Optional) Show user location if you want:
            UserAnnotation()
        }
    }

    private func recenterCamera() {
        camera = .region(mapRegion)
    }

    private var mapRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: rideManager.liveDriverCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }

    /// Coordinates for the current leg line (driver -> pickup, then driver -> dropoff).
    private var legPolyline: [CLLocationCoordinate2D]? {
        guard let ride = rideManager.currentRide else { return nil }
        switch ride.status {
        case .enRouteToPickup:
            guard let pickup = rideManager.pickupCoordinate else { return nil }
            return [rideManager.liveDriverCoordinate, pickup]
        case .enRouteToDropoff:
            guard let drop = rideManager.dropoffCoordinate else { return nil }
            return [rideManager.liveDriverCoordinate, drop]
        default:
            return nil
        }
    }

    // MARK: - Panel

    private var panel: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let ride = rideManager.currentRide {
                // Header
                HStack(alignment: .top, spacing: 12) {
                    // Driver avatar placeholder
                    ZStack {
                        Circle().fill(Color(.systemGray5)).frame(width: 44, height: 44)
                        Text(String(ride.driver.name.prefix(1)))
                            .font(.headline)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(ride.driver.name)
                                .font(.title3).bold()
                            Spacer()
                            Text(String(format: "$%.2f", ride.fare))
                                .font(.title3).bold()
                        }
                        HStack(spacing: 6) {
                            Text(ride.driver.carMakeModel)
                            Image(systemName: "star.fill").font(.caption2)
                            Text(String(format: "%.1f", ride.driver.rating))
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                // Compliments
                if !ride.driver.compliments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ride.driver.compliments, id: \.self) { c in
                                smallPill("sparkles", c)
                            }
                        }
                    }
                }

                // Paying with
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paying with")
                        .font(.headline)
                    HStack(spacing: 10) {
                        Image(systemName: "creditcard.fill")
                        let card = rideManager.savedCards[min(rideManager.selectedCardIndex, max(rideManager.savedCards.count-1, 0))]
                        Text("\(card.brand) ••\(card.last4)")
                        Spacer()
                        Menu("Change") {
                            ForEach(Array(rideManager.savedCards.enumerated()), id: \.offset) { idx, c in
                                Button("\(c.brand) ••\(c.last4)") {
                                    rideManager.selectedCardIndex = idx
                                }
                            }
                        }
                    }
                }

                // Contact + Share + Cancel row
                HStack(spacing: 14) {
                    Button { showChat = true } label: { bigPill("message.fill", "Message") }
                    Button { callDriver() } label: { bigPill("phone.fill", "Call") }
                    Spacer()
                    Button(role: .destructive) { rideManager.riderCancelAndAutoReassign() } label: {
                        bigPill("xmark.circle.fill", "Cancel")
                    }
                }

                // Trip options (stubs)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trip options").font(.headline)
                    HStack(spacing: 10) {
                        Button { /* hook: present picker */ } label: { smallPill("mappin.and.ellipse", "Change pickup") }
                        Button { /* hook: present picker */ } label: { smallPill("flag.checkered", "Change dropoff") }
                        Button { /* hook: add stop */ } label: { smallPill("plus", "Add stop") }
                    }
                }

                // Share ETA
                Button { shareRide() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share status & ETA (\(etaText))")
                    }
                }
                .buttonStyle(.bordered)

                // Report issue
                Button { showReportAlert = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Report an incident")
                    }
                }
                .buttonStyle(.bordered)

                // Subtle status footer
                Text(statusFooter)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    // MARK: - Status / ETA

    private var statusFooter: String {
        guard let ride = rideManager.currentRide else { return "" }
        switch ride.status {
        case .enRouteToPickup:  return "Your driver is on the way to your pickup."
        case .enRouteToDropoff: return "You’re on the way to your destination."
        case .completed:        return "Ride completed."
        case .cancelled:        return "Ride cancelled."
        }
    }

    private var etaText: String {
        let min = max(1, Int(rideManager.remainingMinutesRounded))
        return "\(min) min"
    }

    // MARK: - Helpers

    private func smallPill(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.footnote)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
    }

    private func bigPill(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private func shareRide() {
        let text = "I’m on a Rydr trip: \(rideManager.currentRide?.pickup ?? "") → \(rideManager.currentRide?.dropoff ?? "")"
        let avc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.rootViewController?
            .present(avc, animated: true)
    }

    private func callDriver() {
        // Replace with masked calling later
        if let url = URL(string: "tel://55550100") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Minimal in-app chat mock

    private struct ChatSheet: View {
        @State private var text = ""
        @State private var messages: [String] = ["Driver: On my way!", "You: Great, thanks."]

        var body: some View {
            VStack {
                List(messages, id: \.self) { Text($0) }
                HStack {
                    TextField("Message", text: $text)
                        .textFieldStyle(.roundedBorder)
                    Button("Send") {
                        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        messages.append("You: \(text)")
                        text = ""
                    }
                }
                .padding()
            }
            .presentationDetents([.medium, .large])
        }
    }
}


