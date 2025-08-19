//
//  ProfileView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/11/25.
//
//
//  ProfileView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/11/25.
//
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - ProfileView
struct ProfileView: View {
    @EnvironmentObject var session: UserSessionManager

    @State private var showImagePicker = false
    @State private var pickedUIImage: UIImage?
    @State private var profileImage: Image? = Image(systemName: "person.crop.circle.fill")

    // Preferences (local for now; we’ll wire to Firestore later)
    @State private var musicType: String = "No preference"
    @State private var climate: String = "Neutral"
    @State private var conversation: String = "Light"
    @State private var driverPref: String = "No preference"

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {

                    // Header: avatar + greeting
                    HStack(spacing: 16) {
                        Button { showImagePicker = true } label: {
                            (profileImage ?? Image(systemName: "person.crop.circle.fill"))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray.opacity(0.25), lineWidth: 1))
                                .shadow(radius: 2)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hello, \(session.userName)")
                                .font(.title3).bold()
                            Text("View and manage your account")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Section: Account (tiles)
                    SectionHeader(title: "Account")
                    TileGrid(columns: 2, tiles: [
                        .init(title: "Personal Information", icon: "person.text.rectangle", destination: AnyView(PersonalInfoView())),
                        .init(title: "Ride History & Receipts", icon: "clock.arrow.circlepath", destination: AnyView(Text("Coming soon").navigationTitle("Ride History"))),
                        .init(title: "Payment Methods", icon: "creditcard", destination: AnyView(AddPaymentNoSkipView())),
                        .init(title: "Notifications", icon: "bell.badge", destination: AnyView(Text("Coming soon").navigationTitle("Notifications"))),
                        .init(title: "Settings", icon: "gearshape", destination: AnyView(SettingsView()))
                    ])

                    // Section: Features (tiles)
                    SectionHeader(title: "Features")
                    TileGrid(columns: 2, tiles: [
                        .init(title: "SafeRydr Mode", icon: "shield.lefthalf.filled", destination: AnyView(SafeRydrView())),
                        .init(title: "RydrBank", icon: "banknote", destination: AnyView(RydrBankView())),
                        .init(title: "Help & Support", icon: "questionmark.circle", destination: AnyView(Text("Coming soon").navigationTitle("Help & Support"))),
                        .init(title: "Community (Local Events)", icon: "person.3.sequence", destination: AnyView(Text("Coming soon").navigationTitle("Community")))
                    ])

                    // Section: Preferences
                    preferencesCard

                    // Logout
                    Button {
                        session.logout()
                    } label: {
                        Text("Log Out")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }
                .navigationTitle("Profile")
            }
        }
        .onAppear { session.loadUserProfile() }
        .sheet(isPresented: $showImagePicker, onDismiss: didPickPhoto) {
            ImagePicker(selectedImage: $pickedUIImage, sourceType: .photoLibrary)
        }
    }

    // MARK: - Preferences card
    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Preferences")

            VStack(spacing: 12) {
                PreferencePicker(title: "Type of Music", selection: $musicType,
                                 options: ["No preference", "Hip-Hop", "R&B", "Pop", "Country", "Jazz", "Podcast"])
                PreferencePicker(title: "Climate Control", selection: $climate,
                                 options: ["Cool", "Neutral", "Warm"])
                PreferencePicker(title: "Conversation", selection: $conversation,
                                 options: ["Silence", "Light", "Talkative"])
                PreferencePicker(title: "Driver", selection: $driverPref,
                                 options: ["No preference", "Male", "Female"])
            }
            .padding(.horizontal)

            Button {
                // Next step: persist to Firestore (users/{uid}/preferences).
            } label: {
                Text("Save Preferences")
                    .font(.subheadline).bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Styles.rydrGradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.bottom, 6)
        }
        .padding(.top, 2)
    }

    // MARK: - Image picker handler
    private func didPickPhoto() {
        guard let ui = pickedUIImage else { return }
        profileImage = Image(uiImage: ui)
        // TODO: Upload to Firebase Storage and save photoURL on users/{uid}.
    }
}

// MARK: - Section header with gradient
struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(Styles.rydrGradient)
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Tile Grid + Card
struct TileItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let destination: AnyView
}

struct TileGrid: View {
    let columns: Int
    let tiles: [TileItem]

    private var grid: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 12), count: columns) }

    var body: some View {
        LazyVGrid(columns: grid, spacing: 12) {
            ForEach(tiles) { tile in
                NavigationLink {
                    tile.destination
                } label: {
                    TileCard(title: tile.title, icon: tile.icon)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }
}

struct TileCard: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Styles.rydrGradient.opacity(0.12))
                    .frame(height: 54)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Styles.rydrGradient)
            }
            Text(title)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(.primary)
                .padding(.horizontal, 6)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
        )
    }
}

// MARK: - Preference Picker row
struct PreferencePicker: View {
    let title: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline).bold()
                .foregroundStyle(.primary)
            Menu {
                ForEach(options, id: \.self) { opt in
                    Button(opt) { selection = opt }
                }
            } label: {
                HStack {
                    Text(selection)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
            }
        }
    }
}

// MARK: - Settings (kept local unless you already have one elsewhere)
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

// MARK: - Add Payment from Profile (no "skip")
/// Wrapper that opens your PaymentMethodView via SetupIntent, without any skip path.
struct AddPaymentNoSkipView: View {
    @State private var clientSecret: String?
    @State private var isPresentingSheet = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Payment Methods")
                .font(.title3).bold()

            Text("Add a card to use for future rides.")
                .foregroundStyle(.secondary)

            Button {
                fetchSetupIntent()
            } label: {
                Text("Add Payment Method")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            if isLoading { ProgressView("Loading…") }
            if let e = errorMessage { Text("⚠️ \(e)").foregroundColor(.red) }
        }
        .padding()
        .navigationTitle("Payment Methods")
        .sheet(isPresented: $isPresentingSheet) {
            if let secret = clientSecret {
                PaymentMethodView(clientSecret: secret) { result in
                    isPresentingSheet = false
                    switch result {
                    case .success:
                        // Optionally show a confirmation or pop the view.
                        break
                    case .failure:
                        errorMessage = "Payment not added. You can try again."
                    }
                }
            }
        }
    }

    // Same SetupIntent flow your PaymentScreenView uses, minus any skip behavior.
    private func fetchSetupIntent() {
        isLoading = true
        errorMessage = nil

        guard let user = Auth.auth().currentUser else {
            errorMessage = "User not logged in"
            isLoading = false
            return
        }
        let uid = user.uid
        Firestore.firestore().collection("users").document(uid).getDocument { doc, error in
            if let error = error {
                errorMessage = "Firestore error: \(error.localizedDescription)"
                isLoading = false
                return
            }
            guard let customerId = doc?.data()?["stripeCustomerId"] as? String else {
                errorMessage = "No Stripe customer ID found"
                isLoading = false
                return
            }

            var request = URLRequest(url: URL(string: "https://rydr-stripe-backend.onrender.com/create-setup-intent")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["customerId": customerId])

            URLSession.shared.dataTask(with: request) { data, _, error in
                DispatchQueue.main.async {
                    isLoading = false
                    if let error = error { errorMessage = error.localizedDescription; return }
                    guard let data = data else { errorMessage = "No data received"; return }
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: String],
                           let secret = json["clientSecret"] {
                            clientSecret = secret
                            isPresentingSheet = true
                        } else {
                            errorMessage = "Invalid response format"
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }.resume()
        }
    }
}








