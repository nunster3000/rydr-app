//
//  ContentView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/11/25.
//
import SwiftUI
import MapKit

struct Shortcut: Identifiable, Codable, Equatable {
    var id: UUID = UUID() // make it var, not let
    let label: String
    let value: String
    let icon: String
}

struct BookingView: View {
    @State private var pickupLocation = ""
    @State private var dropOffLocation = ""
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.6407, longitude: -84.4277),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @AppStorage("shortcuts") private var shortcutsData: Data = Data()
    @State private var shortcuts: [Shortcut] = [
        Shortcut(label: "Home", value: "123 Main St", icon: "house.fill"),
        Shortcut(label: "Work", value: "456 Office Blvd", icon: "briefcase.fill"),
        Shortcut(label: "Custom", value: "789 Park Lane", icon: "mappin.and.ellipse")
    ]
    
    @State private var showDriverSelection = false
    @State private var selectedDriver: Driver?
    @State private var nearbyDrivers: [Driver] = [
        Driver(id: "1", name: "Alex", profileImage: "driver1", carImage: "car1", rating: 4.8, perMinute: 0.5, perMile: 1.2, driverScore: 88),
        Driver(id: "2", name: "Jamie", profileImage: "driver2", carImage: "car2", rating: 4.5, perMinute: 0.6, perMile: 1.1, driverScore: 72),
        Driver(id: "3", name: "Morgan", profileImage: "driver3", carImage: "car3", rating: 4.9, perMinute: 0.4, perMile: 1.3, driverScore: 94)
    ]
    
    var rideType: String
    var userName: String = "Khris"
    
    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                UserAnnotation()
            }
            .mapControls { MapUserLocationButton() }
            .ignoresSafeArea()
            
            Color.gray.opacity(0.7).ignoresSafeArea()
            
            VStack(spacing: 16) {
                Text("Ready to ride, \(userName)?")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(
                        LinearGradient(colors: [.red, Color(red: 0.5, green: 0, blue: 0.13).opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                    )
                    .padding(.top, 50)
                
                // Shortcuts
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(shortcuts) { shortcut in
                            ShortcutButton(label: shortcut.label, icon: shortcut.icon) {
                                if pickupLocation.isEmpty {
                                    pickupLocation = shortcut.value
                                } else {
                                    dropOffLocation = shortcut.value
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                // Location Inputs
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Enter Pickup Location", text: $pickupLocation)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Add as Shortcut") {
                        let newShortcut = Shortcut(label: "Custom", value: pickupLocation, icon: "mappin.and.ellipse")
                        if !shortcuts.contains(newShortcut) {
                            shortcuts.append(newShortcut)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    
                    TextField("Enter Drop-off Location", text: $dropOffLocation)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Image(systemName: "car.fill")
                            .foregroundColor(.red)
                        Text(rideType)
                            .font(.title3)
                            .bold()
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, Color(red: 0.5, green: 0, blue: 0.13).opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
                .padding()
                .background(Color.white.opacity(0.9))
                .cornerRadius(12)
                .shadow(radius: 5)
                .padding(.horizontal)
                
                // Book Ride
                Button(action: {
                    showDriverSelection = true
                }) {
                    Text("Book Ride")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.red, Color(red: 0.5, green: 0, blue: 0.13).opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
            
            if showDriverSelection {
                Group {
                    DriverSelectionView(
                        drivers: nearbyDrivers,
                        onConfirm: { driver in
                            selectedDriver = driver
                            showDriverSelection = false
                            
                            // Authorize payment before moving forward
                            authorizePayment(for: driver) {
                                navigateToRideInProgress()
                            }
                        }
                    )
                }
                .background(Color.white)
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }
        }
    }
            
            
            func navigateToRideInProgress() {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController = UIHostingController(rootView: Text("🚘 Ride In Progress..."))
                    window.makeKeyAndVisible()
                }
            }
            func authorizePayment(for driver: Driver, completion: @escaping () -> Void) {
                // Call your backend to authorize a payment using the saved Stripe payment method
                // For now, simulate this:
                print("🔐 Authorizing payment for \(driver.name)...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    print("✅ Payment authorized.")
                    completion()
                }
            }
            
            
            // MARK: - Persistence
            func saveShortcuts() {
                if let encoded = try? JSONEncoder().encode(shortcuts) {
                    shortcutsData = encoded
                }
            }
            
            func loadShortcuts() {
                if let decoded = try? JSONDecoder().decode([Shortcut].self, from: shortcutsData) {
                    shortcuts = decoded
                } else {
                    // Default fallback shortcuts
                    shortcuts = [
                        Shortcut(label: "Home", value: "123 Main St", icon: "house.fill"),
                        Shortcut(label: "Work", value: "456 Office Blvd", icon: "briefcase.fill"),
                        Shortcut(label: "Custom", value: "789 Park Lane", icon: "mappin.and.ellipse")
                    ]
                }
            }
        }
    
    struct ShortcutButton: View {
        let label: String
        let icon: String
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 4) {
                    LinearGradient(
                        colors: [.red, Color(red: 0.5, green: 0.0, blue: 0.13).opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .mask(
                        Image(systemName: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    )
                    
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(
                            LinearGradient(colors: [.red, Color(red: 0.5, green: 0.0, blue: 0.13).opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                        )
                }
                .padding(8)
                .frame(width: 70, height: 70)
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
            }
        }
    }



