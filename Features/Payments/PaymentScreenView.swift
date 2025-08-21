//
//  PaymentScreenView.swift
//  RydrPlayground
//

import SwiftUI
import Stripe
import StripePaymentSheet
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct PaymentScreenView: View {
    var onComplete: () -> Void
    var onSkip: () -> Void = { }
    var showSkip: Bool = true

    @State private var clientSecret: String?
    @State private var ephemeralKeySecret: String?
    @State private var customerId: String?

    @State private var isPresentingPaymentSheet = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Your deployed backend
    private let backendBase = URL(string: "https://rydr-stripe-backend.onrender.com")!

    var body: some View {
        VStack(spacing: 18) {
            Text("Payment Methods").font(.largeTitle).bold()
            Text("Add a card to use for future rides. You can remove it anytime.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                startSetupFlow()
            } label: {
                Text("Add Payment Method").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if showSkip {
                Button("Add Payment Later") { onSkip() }
                    .frame(maxWidth: .infinity)
            }

            if isLoading { ProgressView("Working…") }
            if let err = errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .padding()
        .sheet(isPresented: $isPresentingPaymentSheet) {
            if let secret = clientSecret {
                PaymentMethodView(
                    clientSecret: secret,
                    customerId: customerId,
                    ephemeralKeySecret: ephemeralKeySecret
                ) { result in
                    isPresentingPaymentSheet = false
                    switch result {
                    case .success: onComplete()
                    case .failure(let e):
                        errorMessage = e.localizedDescription
                        if showSkip { onSkip() }
                    }
                }
            }
        }
    }

    // MARK: - Full flow
    private func startSetupFlow() {
        isLoading = true
        errorMessage = nil

        guard let user = Auth.auth().currentUser else {
            fail("You must be logged in.")
            return
        }

        fetchOrCreateCustomer(for: user) { result in
            switch result {
            case .failure(let err):
                self.fail(err.localizedDescription)

            case .success(let cid):
                self.customerId = cid

                // 1) Ephemeral key (for customer-aware PaymentSheet)
                self.requestJSON(
                    path: "ephemeral-key",
                    body: ["customerId": cid],
                    extraHeaders: ["Stripe-Version": "2024-06-20"]
                ) { (ek: EphemeralKeyResponse?) in
                    self.ephemeralKeySecret = ek?.secret // optional but recommended

                    // 2) SetupIntent (to save a card)
                    self.requestJSON(
                        path: "create-setup-intent",
                        body: ["customerId": cid]
                    ) { (si: SetupIntentResponse?) in
                        DispatchQueue.main.async {
                            self.isLoading = false
                            guard let clientSecret = si?.clientSecret else {
                                self.fail("Invalid SetupIntent response from server.")
                                return
                            }
                            self.clientSecret = clientSecret
                            self.isPresentingPaymentSheet = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Ensure user has a Stripe customer (read Firestore; create/store if missing)
    private func fetchOrCreateCustomer(for user: User, completion: @escaping (Result<String, Error>) -> Void) {
        let uid = user.uid
        let docRef = Firestore.firestore().collection("users").document(uid)

        docRef.getDocument { snap, err in
            if let err = err {
                completion(.failure(err)); return
            }

            if let cid = snap?.data()?["stripeCustomerId"] as? String, !cid.isEmpty {
                completion(.success(cid))
                return
            }

            // No customer stored — create/reuse by email on backend, then save to Firestore
            let email = user.email ?? "user-\(uid)@example.com"
            let name  = user.displayName ?? "Rydr User"

            self.requestJSON(path: "create-customer", body: ["email": email, "name": name]) { (resp: CreateCustomerResponse?) in
                guard let cid = resp?.customerId, !cid.isEmpty else {
                    completion(.failure(NSError(domain: "Stripe", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server returned no customerId."])))
                    return
                }
                docRef.setData(["stripeCustomerId": cid], merge: true) { writeErr in
                    if let writeErr = writeErr { completion(.failure(writeErr)) }
                    else { completion(.success(cid)) }
                }
            }
        }
    }

    // MARK: - Networking helper
    private func requestJSON<T: Decodable>(
        path: String,
        body: [String: Any],
        extraHeaders: [String: String] = [:],
        completion: @escaping (T?) -> Void
    ) {
        var req = URLRequest(url: backendBase.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in extraHeaders { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data else { completion(nil); return }
            let obj = try? JSONDecoder().decode(T.self, from: data)
            completion(obj)
        }.resume()
    }

    // MARK: - Small UI helper used above
    private func fail(_ message: String) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = message
        }
    }
}

// MARK: - DTOs
private struct CreateCustomerResponse: Decodable { let customerId: String }
private struct SetupIntentResponse: Decodable { let clientSecret: String }
private struct EphemeralKeyResponse: Decodable { let id: String; let secret: String }



