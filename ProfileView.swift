//
//  ProfileView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/11/25.
//
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var session: UserSessionManager
    @State private var profileImage: Image? = Image(systemName: "person.crop.circle.fill")

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {

                    // Profile Picture & Greeting
                    VStack {
                        profileImage?
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                            .shadow(radius: 5)

                        Text("Hello, \(session.userName)")
                            .font(.title2)
                            .bold()
                    }
                    .padding(.top)

                    // Logout Button
                    Button("Logout") {
                        session.logout()
                    }
                    .foregroundColor(.red)
                    .padding(.bottom)

                    // Programs Section
                    SectionHeader(title: "Programs")
                    VStack(spacing: 15) {
                        NavigationLink("SafeRydr Mode", destination: Text("SafeRydr Mode Coming Soon"))
                        NavigationLink("RydrBank", destination: Text("RydrBank Overview"))
                    }
                    .padding(.horizontal)

                    // Account Section
                    SectionHeader(title: "Account")
                    VStack(spacing: 15) {
                        NavigationLink("Notifications", destination: Text("Notification Settings"))
                        NavigationLink("Refer a Friend", destination: Text("Invite & Earn"))
                        NavigationLink("Ride History", destination: Text("Past Trips & Activity"))
                        NavigationLink("Payment", destination: Text("Manage Payment Methods"))
                        NavigationLink("Help", destination: Text("Contact Support"))
                        NavigationLink("Settings", destination: SettingsView())
                    }
                    .padding(.horizontal)

                    // Services Section
                    SectionHeader(title: "Services")
                    VStack(spacing: 15) {
                        NavigationLink("Become a Driver", destination: Text("Driver Signup Flow"))
                        NavigationLink("Share a Banked Ride", destination: Text("Rider Sharing Feature"))
                    }
                    .padding(.horizontal)
                }
                .navigationTitle("Profile")
            }
            // 💳 Payment Section
            Section(header: Text("Payment")) {
                NavigationLink(destination: PaymentScreenView()) {
                    Label("Payment Method", systemImage: "creditcard.fill")
                        .foregroundColor(.primary)
                }
            }
            List {
                // 👤 Account Section
                Section(header: Text("Account")) {
                    // ... existing links
                }

                // 💳 Payment Section
                Section(header: Text("Payment")) {
                    NavigationLink(destination: PaymentScreenView()) {
                        Label("Payment Method", systemImage: "creditcard.fill")
                            .foregroundColor(.primary)
                    }
                }

                // 🧭 Services Section
                Section(header: Text("Services")) {
                    // ... existing links
                }
            }

        }
    }
}

// MARK: - Section Header View
struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.red, Color.red.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Placeholder Settings View
struct SettingsView: View {
    var body: some View {
        List {
            Toggle("Dark Mode", isOn: .constant(false))
            Toggle("Location Services", isOn: .constant(true))
            Toggle("Face ID for Login", isOn: .constant(true))
        }
        .navigationTitle("Settings")
    }
}


// MARK: - Preview
#Preview {
    ProfileView()
        .environmentObject(UserSessionManager())
}



