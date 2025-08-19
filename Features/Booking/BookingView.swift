//
//  ContentView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/11/25.
//
//
//  BookingView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/11/25.
//
import SwiftUI
import MapKit
import _MapKit_SwiftUI
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

struct Shortcut: Identifiable {
    let id = UUID()
    let label: String
    var value: String?
    let icon: String
}

struct BookingView: View {
    var rideType: String
    var userName: String

    @StateObject private var locationManager = LocationManager()
    @StateObject private var userViewModel = UserViewModel()
    @StateObject private var pickupSearch = LocationSearchService()
    @StateObject private var dropoffSearch = LocationSearchService()
    @StateObject private var shortcutSearch = LocationSearchService()

    @FocusState private var pickupFocused: Bool
    @FocusState private var dropoffFocused: Bool

    @State private var pickupLocation = ""
    @State private var dropOffLocation = ""
    @State private var showDriverSelection = false
    @State private var selectedDriver: Driver?
    @State private var showingShortcutInput: Shortcut?
    @State private var showingShortcutOptions: Shortcut?
    @State private var recentAddresses: [String] = []

    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 33.6407, longitude: -84.4277),
                           span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
    )

    @State private var bottomSheetOffset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    @State private var nearbyDrivers: [Driver] = [
        Driver(id: "1", name: "Alex", profileImage: "driver1", carImage: "car1", rating: 4.8, perMinute: 0.5, perMile: 1.2, driverScore: 88),
        Driver(id: "2", name: "Jamie", profileImage: "driver2", carImage: "car2", rating: 4.5, perMinute: 0.6, perMile: 1.1, driverScore: 72),
        Driver(id: "3", name: "Morgan", profileImage: "driver3", carImage: "driver3", rating: 4.9, perMinute: 0.4, perMile: 1.3, driverScore: 94)
    ]
    
    @State private var showRideInProgress = false
    @State private var shortcuts: [Shortcut] = [
        Shortcut(label: "Home", value: nil, icon: "house.fill"),
        Shortcut(label: "Work", value: nil, icon: "briefcase.fill"),
        Shortcut(label: "Custom", value: nil, icon: "mappin.and.ellipse")
    ]

    // MARK: - Promo (RydrBank) state
    @State private var promoInput: String = ""
    @State private var appliedPromoCode: String? = nil
    @State private var promoMessage: String? = nil
    @State private var isApplyingPromo = false

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                UserAnnotation()
            }
            .mapControls { MapUserLocationButton() }
            .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 20) {
                    Capsule()
                        .frame(width: 40, height: 6)
                        .foregroundColor(.gray.opacity(0.4))

                    Text("Ready to ride, \(userViewModel.userName)?")
                        .font(.headline)

                    // Shortcuts
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(shortcuts.indices, id: \.self) { index in
                                let shortcut = shortcuts[index]
                                ShortcutButton(
                                    label: shortcut.label,
                                    icon: shortcut.icon,
                                    tapAction: {
                                        if shortcut.value == nil {
                                            showingShortcutInput = shortcuts[index]
                                        } else {
                                            if pickupLocation.isEmpty {
                                                pickupLocation = shortcut.value!
                                                pickupSearch.queryFragment = shortcut.value!
                                            } else if dropOffLocation.isEmpty {
                                                dropOffLocation = shortcut.value!
                                                dropoffSearch.queryFragment = shortcut.value!
                                            }
                                        }
                                    },
                                    longPressAction: {
                                        showingShortcutOptions = shortcuts[index]
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Address fields + recents
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Enter Pickup Location", text: $pickupSearch.queryFragment)
                            .textFieldStyle(.roundedBorder)
                            .focused($pickupFocused)

                        if pickupFocused && !pickupSearch.suggestions.isEmpty {
                            List(pickupSearch.suggestions, id: \.self) { suggestion in
                                Button(action: {
                                    resolveAddress(suggestion) { resolved in
                                        pickupLocation = resolved
                                        pickupSearch.queryFragment = resolved
                                        pickupFocused = false
                                    }
                                }) {
                                    Text(suggestion.title + ", " + suggestion.subtitle)
                                }
                            }
                            .frame(maxHeight: 150)
                        }

                        Button("Use Current Location") {
                            if let location = locationManager.currentLocation {
                                let coordinate = location.coordinate
                                locationManager.getAddress(for: coordinate) { address in
                                    pickupLocation = address ?? "Current Location"
                                    pickupSearch.queryFragment = pickupLocation
                                    cameraPosition = .region(MKCoordinateRegion(center: coordinate,
                                                                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
                                }
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)

                        TextField("Enter Drop-off Location", text: $dropoffSearch.queryFragment)
                            .textFieldStyle(.roundedBorder)
                            .focused($dropoffFocused)

                        if dropoffFocused && !dropoffSearch.suggestions.isEmpty {
                            List(dropoffSearch.suggestions, id: \.self) { suggestion in
                                Button(action: {
                                    resolveAddress(suggestion) { resolved in
                                        dropOffLocation = resolved
                                        dropoffSearch.queryFragment = resolved
                                        addToRecents(resolved)
                                        dropoffFocused = false
                                    }
                                }) {
                                    Text(suggestion.title + ", " + suggestion.subtitle)
                                }
                            }
                            .frame(maxHeight: 150)
                        }

                        if !recentAddresses.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Recents")
                                    .font(.subheadline).bold()
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(recentAddresses.prefix(5), id: \.self) { address in
                                            Button(address) {
                                                dropOffLocation = address
                                                dropoffSearch.queryFragment = address
                                            }
                                            .padding(8)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                                Button("View More") { }
                                    .font(.caption)
                            }
                        }

                        HStack {
                            Image(systemName: "car.fill").foregroundColor(.red)
                            Text(rideType).bold()
                        }
                    }
                    .padding(.horizontal)

                    // MARK: - Promo code section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Have a promo?")
                                .font(.subheadline).bold()
                            if let applied = appliedPromoCode {
                                Text("• Applied: \(applied)")
                                    .font(.footnote)
                                    .foregroundColor(.green)
                            }
                            Spacer()
                        }

                        HStack(spacing: 8) {
                            TextField("Enter code", text: $promoInput)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .textFieldStyle(.roundedBorder)

                            if appliedPromoCode == nil {
                                Button {
                                    Task { await applyPromo() }
                                } label: {
                                    if isApplyingPromo {
                                        ProgressView()
                                    } else {
                                        Text("Apply")
                                    }
                                }
                                .disabled(promoInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isApplyingPromo)
                            } else {
                                Button("Clear") {
                                    Task { await clearPromo() }
                                }
                                .foregroundColor(.red)
                            }
                        }

                        if let msg = promoMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    Button(action: {
                        showDriverSelection = true
                    }) {
                        Text("Book Ride")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .shadow(radius: 5)
                .offset(y: max(0, bottomSheetOffset + dragOffset))
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in state = value.translation.height }
                        .onEnded { value in
                            let threshold: CGFloat = 150
                            bottomSheetOffset = value.translation.height > threshold ? 300 : 0
                        }
                )
            }
        }
        .actionSheet(item: $showingShortcutOptions) { shortcut in
            ActionSheet(title: Text("Edit \(shortcut.label)"), buttons: [
                .default(Text("Edit Details")) { showingShortcutInput = shortcut },
                .cancel()
            ])
        }
        .sheet(item: $showingShortcutInput) { shortcut in
            VStack(spacing: 16) {
                Text("Set address for \(shortcut.label)")
                    .font(.headline)
                TextField("Search address", text: $shortcutSearch.queryFragment)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                if !shortcutSearch.suggestions.isEmpty {
                    List(shortcutSearch.suggestions, id: \.self) { suggestion in
                        Button(action: {
                            resolveAddress(suggestion) { resolved in
                                if let index = shortcuts.firstIndex(where: { $0.label == shortcut.label }) {
                                    shortcuts[index].value = resolved
                                }
                                shortcutSearch.queryFragment = ""
                                showingShortcutInput = nil
                            }
                        }) {
                            Text(suggestion.title + ", " + suggestion.subtitle)
                        }
                    }
                    .frame(maxHeight: 150)
                }
                Button("Cancel") { showingShortcutInput = nil }
                    .padding()
            }
            .padding()
        }
        .onAppear {
            locationManager.requestLocation()
            if let location = locationManager.currentLocation {
                pickupSearch.updateRegion(location.coordinate)
                dropoffSearch.updateRegion(location.coordinate)
                shortcutSearch.updateRegion(location.coordinate)
            }
        }
        .fullScreenCover(isPresented: $showDriverSelection) {
            DriverSelectionView(
                drivers: nearbyDrivers,
                onConfirm: { driver in
                    selectedDriver = driver
                    showDriverSelection = false
                    // If you want, you can re-preview the promo here against chosen driver’s tier.
                    showRideInProgress = true
                }
            )
        }
        .fullScreenCover(isPresented: $showRideInProgress) {
            if let driver = selectedDriver {
                RideInProgressView(driver: driver)
            }
        }
    }

    // MARK: - Helpers

    private func resolveAddress(_ suggestion: MKLocalSearchCompletion, completion: @escaping (String) -> Void) {
        let request = MKLocalSearch.Request(completion: suggestion)
        MKLocalSearch(request: request).start { response, _ in
            if let coordinate = response?.mapItems.first?.placemark.coordinate {
                locationManager.getAddress(for: coordinate) { address in
                    completion(address ?? "\(coordinate.latitude), \(coordinate.longitude)")
                    cameraPosition = .region(MKCoordinateRegion(center: coordinate,
                                                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
                }
            }
        }
    }

    private func addToRecents(_ address: String) {
        if !recentAddresses.contains(address) {
            recentAddresses.insert(address, at: 0)
            if recentAddresses.count > 15 { recentAddresses.removeLast() }
        }
    }

    // MARK: - Promo API calls

    /// Validate + reserve the promo. Server should mark code "reserved" for this user.
    private func applyPromo() async {
        guard !promoInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isApplyingPromo = true
        promoMessage = nil
        do {
            guard let user = Auth.auth().currentUser else {
                promoMessage = "Please sign in to use a promo."
                isApplyingPromo = false
                return
            }
            let idToken = try await user.getIDToken()
            var req = URLRequest(url: URL(string: "https://your-backend.example.com/promo/preview")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            // You can send driver/tier and rough distance if you want a discount preview now.
            let body: [String: Any] = [
                "code": promoInput.trimmingCharacters(in: .whitespacesAndNewlines),
                "rideType": rideType
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                // Optional: parse preview amount from server response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let previewText = json["message"] as? String {
                    promoMessage = previewText
                } else {
                    promoMessage = "RydrBank applied: up to 15 miles free on your next ride."
                }
                appliedPromoCode = promoInput.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                promoMessage = "Invalid or unavailable code."
                appliedPromoCode = nil
            }
        } catch {
            promoMessage = "Network error. Please try again."
            appliedPromoCode = nil
        }
        isApplyingPromo = false
    }

    /// Release reservation (if any) when the user clears the promo or backs out.
    private func clearPromo() async {
        guard let current = appliedPromoCode else {
            // nothing to release, just clear the field
            promoInput = ""
            promoMessage = nil
            return
        }
        do {
            guard let user = Auth.auth().currentUser else { return }
            let idToken = try await user.getIDToken()
            var req = URLRequest(url: URL(string: "https://your-backend.example.com/promo/release")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            req.httpBody = try JSONSerialization.data(withJSONObject: ["code": current])

            _ = try await URLSession.shared.data(for: req)
        } catch {
            // Even if release fails, clear locally so the UI doesn’t trap the user
        }
        appliedPromoCode = nil
        promoInput = ""
        promoMessage = nil
    }
}

struct ShortcutButton: View {
    let label: String
    let icon: String
    let tapAction: () -> Void
    let longPressAction: () -> Void

    var body: some View {
        Button(action: tapAction) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                Text(label)
                    .font(.caption2)
            }
            .padding(8)
            .frame(width: 70, height: 70)
            .background(Color.white)
            .cornerRadius(10)
        }
        .simultaneousGesture(
            LongPressGesture().onEnded { _ in longPressAction() }
        )
    }
}







