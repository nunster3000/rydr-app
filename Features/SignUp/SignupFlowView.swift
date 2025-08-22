//
//  SignupFlowView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 8/22/25.
//


import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SignupFlowView: View {
    @StateObject private var coordinator = SignupCoordinator()

    var body: some View {
        VStack {
            switch coordinator.step {
            case .createAccount:
                CreateAccountView(coordinator: coordinator)

            case .addressEntry:
                // Replace with your real address screen if you have one.
                AddressEntryPlaceholder(coordinator: coordinator)

            case .done:
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("All set!")
                        .font(.title2).bold()
                    Text("Your account has been created.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if coordinator.isLoading {
                ProgressView("Working…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert("Error", isPresented: .constant(coordinator.errorMessage != nil), presenting: coordinator.errorMessage) { _ in
            Button("OK") { coordinator.errorMessage = nil }
        } message: { msg in
            Text(msg)
        }
    }
}

// MARK: - Create Account form

private struct CreateAccountView: View {
    @ObservedObject var coordinator: SignupCoordinator

    @State private var firstName = ""
    @State private var lastName  = ""
    @State private var preferred = ""
    @State private var phone     = ""
    @State private var email     = ""
    @State private var password  = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                TextField("First name", text: $firstName)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                TextField("Last name", text: $lastName)
                    .textContentType(.familyName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                TextField("Preferred name (optional)", text: $preferred)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                TextField("Phone (optional)", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)

                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Password", text: $password)
                    .textContentType(.newPassword)

                Button {
                    coordinator.signUp(
                        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                        password: password,
                        firstName: firstName,
                        lastName: lastName,
                        preferredName: preferred.isEmpty ? nil : preferred,
                        phoneNumber: phone.isEmpty ? nil : phone
                    )
                } label: {
                    Text("Create account")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(coordinator.isLoading || email.isEmpty || password.isEmpty || firstName.isEmpty || lastName.isEmpty)

                Text("By continuing you agree to the Terms.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            .textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - Address placeholder (replace with your real screen)

private struct AddressEntryPlaceholder: View {
    @ObservedObject var coordinator: SignupCoordinator

    var body: some View {
        VStack(spacing: 16) {
            Text("Address entry goes here.")
                .foregroundStyle(.secondary)
            Button("Finish") {
                coordinator.step = .done
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
