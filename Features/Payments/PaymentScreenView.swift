//
//  PaymentScreenView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/21/25.
//
import SwiftUI
import Stripe
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct PaymentScreenView: View {
    var onComplete: () -> Void
    var onSkip: () -> Void = { }  // keeps old call sites working

    // NEW: control whether “Add Payment Later” is shown
    var showSkip: Bool = true

    @State private var clientSecret: String?
    @State private var isPresentingPaymentSheet = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Add a Payment Method")
                .font(.title2).bold()

            // Copy adapts to context
            Text(showSkip
                 ? "You can add one now or skip and add later from Profile → Payment."
                 : "Add a card to use for future rides.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                fetchSetupIntent()
            } label: {
                Text("Add Payment Method")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            // Show Skip only when allowed (signup flow)
            if showSkip {
                Button("Add Payment Later") { onSkip() }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }

            if isLoading { ProgressView("Loading...") }

            if let error = errorMessage {
                Text("⚠️ \(error)").foregroundColor(.red)
            }
        }
        .padding()
        .sheet(isPresented: $isPresentingPaymentSheet) {
            if let clientSecret = clientSecret {
                PaymentMethodView(clientSecret: clientSecret) { result in
                    isPresentingPaymentSheet = false
                    switch result {
                    case .success:
                        onComplete()
                    case .failure:
                        // If we’re in signup (showSkip == true), allow continuing
                        if showSkip {
                            onSkip()
                        } else {
                            // In Profile flow, don’t “skip” — just show an error
                            errorMessage = "Payment not added. You can try again."
                        }
                    }
                }
            }
        }
    }

    // MARK: - SetupIntent (call your backend)
    private func fetchSetupIntent() {
        isLoading = true
        errorMessage = nil

        guard let user = Auth.auth().currentUser else {
            self.errorMessage = "User not logged in"
            self.isLoading = false
            return
        }

        let uid = user.uid
        Firestore.firestore().collection("users").document(uid).getDocument { doc, error in
            if let error = error {
                self.errorMessage = "Firestore error: \(error.localizedDescription)"
                self.isLoading = false
                return
            }

            guard let customerId = doc?.data()?["stripeCustomerId"] as? String else {
                self.errorMessage = "No Stripe customer ID found for this user"
                self.isLoading = false
                return
            }

            var request = URLRequest(url: URL(string: "https://rydr-stripe-backend.onrender.com/create-setup-intent")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["customerId": customerId])

            URLSession.shared.dataTask(with: request) { data, _, error in
                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    guard let data = data else {
                        self.errorMessage = "No data received"
                        return
                    }
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: String],
                           let secret = json["clientSecret"] {
                            self.clientSecret = secret
                            self.isPresentingPaymentSheet = true
                        } else {
                            self.errorMessage = "Invalid response format"
                        }
                    } catch {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }.resume()
        }
    }
}



