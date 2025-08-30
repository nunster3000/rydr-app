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
import CoreLocation

struct RideInProgressView: View {
    @ObservedObject var rideManager: RideManager
    @Environment(\.dismiss) private var dismiss

    // Camera we can recenter as positions change
    @State private var camera: MapCameraPosition = .automatic

    // Sheets & UI bits
    @State private var showReportAlert = false
    @State private var showChat = false
    @State private var showPaymentSheet = false
    @State private var showNotesSheet = false
    @State private var pickupNotes = ""
    @State private var gateCode = ""
    @State private var showEnd = false

    var body: some View {
        content
            .navigationTitle("Ride in progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { recenterCamera() }
            .onChange(of: rideManager.liveDriverCoordinate.latitude, initial: false) { _, _ in
                recenterCamera()
            }
            .onChange(of: rideManager.liveDriverCoordinate.longitude, initial: false) { _, _ in
                recenterCamera()
            }
            .onChange(of: rideManager.state, initial: false) { _, newState in
                if newState == .completed { showEnd = true }
            }
            // Chat / payment / notes / end sheets
            .sheet(isPresented: $showChat) { ChatSheet() }
            .sheet(isPresented: $showPaymentSheet) {
                PaymentPicker(cards: rideManager.savedCards, selected: $rideManager.selectedCardIndex)
            }
            .sheet(isPresented: $showNotesSheet) {
                PickupNotesSheet(pickupNotes: $pickupNotes, gateCode: $gateCode)
            }
            .sheet(isPresented: $showEnd) {
                EndRideView(ride: rideManager.lastReceipt, onDone: { dismiss() })
            }
            .alert("Report an incident", isPresented: $showReportAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Thanks for the report. Our team will review this trip.")
            }
    }

    // MARK: content (awaiting→pickup vs on the way to drop-off)
    @ViewBuilder
    private var content: some View {
        if rideManager.currentRide?.status == .enRouteToPickup {
            awaitingPickupUI
        } else {
            onTheWayToDropoffUI
        }
    }

    // MARK: Awaiting pickup — features up top, map as a section
    private var awaitingPickupUI: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                riderHeaderRow

                etaRow("Arrives in \(etaText)")

                actionsRow

                tripOptions

                paymentRow

                mapSection

                shareSection

                reportSection
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    // MARK: En-route to drop-off — more focus on navigation
    private var onTheWayToDropoffUI: some View {
        ZStack(alignment: .bottom) {
            map
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                riderHeaderRow
                etaRow("ETA to drop-off: \(etaText)")
                HStack(spacing: 12) {
                    pill("map", "Share status & ETA") { shareRide() }
                    Spacer()
                    pill("exclamationmark.triangle.fill", "Report") { showReportAlert = true }
                }
                .padding(.bottom, 12)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    // MARK: – UI blocks

    private var riderHeaderRow: some View {
        HStack {
            Circle().fill(Color.gray.opacity(0.15))
                .overlay(Text(String(rideManager.currentRide?.driver.name.prefix(1) ?? "D")))
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(rideManager.currentRide?.driver.name ?? "Driver")
                    .font(.headline)
                Text(rideManager.currentRide?.driver.carMakeModel ?? "")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("$\(rideManager.currentRide?.fare ?? 0, specifier: "%.2f")")
                .font(.headline)
        }
    }

    private func etaRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.checkmark")
                .foregroundStyle(Styles.rydrGradient)          // ← gradient accent
            Text(text)
            Spacer()
        }
        .font(.title3).bold()
    }

    private var actionsRow: some View {
        HStack(spacing: 12) {
            pill("message.fill", "Message") { showChat = true }
            pill("phone.fill", "Call") { callDriver() }
            pill("xmark.circle.fill", "Cancel") { rideManager.riderCancelAndAutoReassign() }
        }
    }

    private var tripOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trip options").font(.headline)
            HStack(spacing: 12) {
                pill("mappin.and.ellipse", "Change pickup") { /* hook to your picker */ }
                pill("flag.checkered", "Change dropoff") { /* hook to your picker */ }
                pill("plus", "Add stop") { /* hook */ }
            }
            HStack(spacing: 12) {
                pill("key.fill", "Add gate code") { showNotesSheet = true }
                pill("note.text", "Pickup notes") { showNotesSheet = true }
            }
        }
    }

    private var paymentRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Paying with").font(.headline)
            HStack {
                let card = rideManager.savedCards[min(rideManager.selectedCardIndex, max(0, rideManager.savedCards.count-1))]
                HStack(spacing: 8) {
                    Image(systemName: "creditcard.fill")
                    Text("\(card.brand) ••\(card.last4)")
                }
                Spacer()
                // Gradient "Change" button
                Button("Change") { showPaymentSheet = true }
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Styles.rydrGradient)
                    )
                    .foregroundStyle(.white)
            }
            .font(.title3)
        }
    }

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Map").font(.headline)
            map.frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var shareSection: some View {
        Button { shareRide() } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(Styles.rydrGradient)      // ← gradient icon
                Text("Share status & ETA (\(etaText))")
                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var reportSection: some View {
        Button { showReportAlert = true } label: {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Styles.rydrGradient)      // ← gradient icon
                Text("Report an incident")
                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Map + overlays

    private var map: some View {
        Map(position: $camera) {
            if let coords = legPolyline {
                MapPolyline(coordinates: coords)
                    .stroke(polylineStyle, lineWidth: 6)
            }

            // Driver pin (custom)
            Annotation("", coordinate: rideManager.liveDriverCoordinate) {
                ZStack {
                    Circle().fill(.background).frame(width: 28, height: 28)
                    Image(systemName: "car.fill")
                        .foregroundStyle(Styles.rydrGradient)  // ← gradient car icon
                }
            }

            // Pickup / dropoff markers
            if let pickup = rideManager.pickupCoordinate {
                Marker("Pickup", coordinate: pickup)
                    .tint(.red)
            }
            if let drop = rideManager.dropoffCoordinate {
                Marker("Drop-off", coordinate: drop)
                    .tint(.blue)
            }
        }
    }

    private var polylineStyle: some ShapeStyle {
        if #available(iOS 18.0, *) {
            return Styles.rydrGradient
        } else {
            return Color.red.opacity(0.85) // iOS 17 MapPolyline can't take a gradient directly
        }
    }

    /// Coordinates for the active leg (driver→pickup, then pickup→dropoff)
    private var legPolyline: [CLLocationCoordinate2D]? {
        switch rideManager.currentRide?.status {
        case .enRouteToPickup?:
            guard let pickup = rideManager.pickupCoordinate else { return nil }
            return [rideManager.liveDriverCoordinate, pickup]
        case .enRouteToDropoff?:
            guard let pickup = rideManager.pickupCoordinate,
                  let drop = rideManager.dropoffCoordinate else { return nil }
            return [pickup, drop]
        default:
            return nil
        }
    }

    private func recenterCamera() {
        // Fit both ends of the current leg
        guard let leg = legPolyline, leg.count == 2 else {
            camera = .region(.init(center: rideManager.liveDriverCoordinate,
                                   span: .init(latitudeDelta: 0.05, longitudeDelta: 0.05)))
            return
        }
        let a = leg[0], b = leg[1]
        let center = CLLocationCoordinate2D(latitude: (a.latitude + b.latitude)/2,
                                            longitude: (a.longitude + b.longitude)/2)
        let span = MKCoordinateSpan(latitudeDelta: abs(a.latitude - b.latitude) + 0.05,
                                    longitudeDelta: abs(a.longitude - b.longitude) + 0.05)
        camera = .region(MKCoordinateRegion(center: center, span: span))
    }

    // MARK: small UI bits

    private func pill(_ icon: String, _ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(text)
            }
            .font(.footnote)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Styles.rydrGradient)                 // ← gradient pill background
            )
        }
        .buttonStyle(.plain)
    }

    private var etaText: String {
        let min = max(1, Int(rideManager.remainingMinutesRounded))
        return "\(min) min"
    }

    private func shareRide() {
        let text = "I'm on a Rydr: \(rideManager.currentRide?.pickup ?? "") → \(rideManager.currentRide?.dropoff ?? "")"
        let avc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.rootViewController?
            .present(avc, animated: true)
    }

    private func callDriver() {
        if let url = URL(string: "tel://5550100"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    // Minimal in-app chat mock
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
                        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        messages.append(text); text = ""
                    }
                }
                .padding()
            }
        }
    }

    private struct PaymentPicker: View {
        let cards: [PaymentCard]
        @Binding var selected: Int
        var body: some View {
            Form {
                Section("Choose a card") {
                    ForEach(cards.indices, id: \.self) { i in
                        HStack {
                            Text("\(cards[i].brand) ••\(cards[i].last4)")
                            Spacer()
                            if i == selected { Image(systemName: "checkmark") }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selected = i }
                    }
                }
            }
            .navigationTitle("Payment")
        }
    }

    private struct PickupNotesSheet: View {
        @Binding var pickupNotes: String
        @Binding var gateCode: String
        var body: some View {
            Form {
                Section("Pickup notes") {
                    TextField("e.g. meet by the lobby", text: $pickupNotes)
                }
                Section("Gate code") {
                    TextField("####", text: $gateCode)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Notes")
        }
    }
}




