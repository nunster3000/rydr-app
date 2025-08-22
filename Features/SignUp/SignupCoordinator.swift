//
//  SignupCoordinator.swift
//  RydrPlayground
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class SignupCoordinator: ObservableObject {

    enum Step {
        case createAccount
        case addressEntry
        case done
    }

    // MARK: - Published UI state
    @Published var step: Step = .createAccount
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Config
    private let backendBase = URL(string: "https://rydr-stripe-backend.onrender.com")!
    private let ridersCollection = "riders"   // change to "users" if your schema differs

    // MARK: - Entry point: Email/Password sign up
    func signUp(email: String,
                password: String,
                firstName: String,
                lastName: String,
                preferredName: String?,
                phoneNumber: String?) {

        isLoading = true
        errorMessage = nil

        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self else { return }

            if let ns = error as NSError? {
                // If email already exists, try to sign the user in and proceed
                if ns.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                    Auth.auth().signIn(withEmail: email, password: password) { [weak self] signInResult, signErr in
                        guard let self else { return }
                        if let signErr {
                            self.fail("Sign-in failed: \(signErr.localizedDescription)")
                            return
                        }
                        guard let user = signInResult?.user else {
                            self.fail("Sign-in failed: missing user")
                            return
                        }
                        self.finishAccountSetup(
                            user: user,
                            email: email,
                            firstName: firstName,
                            lastName: lastName,
                            preferredName: preferredName,
                            phoneNumber: phoneNumber
                        )
                    }
                    return
                } else {
                    self.fail(ns.localizedDescription); return
                }
            }

            guard let user = result?.user else {
                self.fail("Account creation failed: missing user"); return
            }

            // Set display name (non-blocking)
            let change = user.createProfileChangeRequest()
            change.displayName = [firstName, lastName].joined(separator: " ").trimmingCharacters(in: .whitespaces)
            change.commitChanges(completion: nil)

            self.finishAccountSetup(
                user: user,
                email: email,
                firstName: firstName,
                lastName: lastName,
                preferredName: preferredName,
                phoneNumber: phoneNumber
            )
        }
    }

    // MARK: - Social sign-in ready
    func handleSignedInUser(_ user: User,
                            firstName: String? = nil,
                            lastName: String? = nil,
                            preferredName: String? = nil,
                            phoneNumber: String? = nil) {
        let email = user.email ?? ""
        finishAccountSetup(
            user: user,
            email: email,
            firstName: firstName ?? (user.displayName ?? "").components(separatedBy: " ").first ?? "",
            lastName: lastName ?? (user.displayName ?? "").components(separatedBy: " ").dropFirst().joined(separator: " "),
            preferredName: preferredName,
            phoneNumber: phoneNumber
        )
    }

    // MARK: - Internal: profile + Stripe provisioning
    private func finishAccountSetup(user: User,
                                    email: String,
                                    firstName: String,
                                    lastName: String,
                                    preferredName: String?,
                                    phoneNumber: String?) {

        let uid = user.uid
        var data: [String: Any] = [
            "uid": uid,
            "email": email,
            "firstName": firstName,
            "lastName": lastName,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let preferredName, !preferredName.isEmpty { data["preferredName"] = preferredName }
        if let phoneNumber, !phoneNumber.isEmpty { data["phoneNumber"] = phoneNumber }

        upsertRider(uid: uid, data: data) { [weak self] ok in
            guard let self else { return }
            // Provision Stripe customer (creates one even if they skip adding a card)
            self.provisionStripeCustomerIfNeeded(for: user) {
                // Advance to next step regardless (we self-heal later if needed)
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.step = .addressEntry
                }
            }
        }
    }

    // MARK: - Firestore helpers
    private func upsertRider(uid: String,
                             data: [String: Any],
                             completion: @escaping (Bool) -> Void) {
        let ref = Firestore.firestore().collection(ridersCollection).document(uid)
        ref.setData(data, merge: true) { err in
            if let err { print("⚠️ Firestore upsert rider failed:", err.localizedDescription); completion(false) }
            else { completion(true) }
        }
    }

    // MARK: - Stripe customer provisioning
    /// Ensures `riders/{uid}.stripeCustomerId` exists by calling your backend /create-customer.
    /// Works even if the user has no card yet.
    private func provisionStripeCustomerIfNeeded(for user: User,
                                                 completion: @escaping () -> Void) {
        let uid = user.uid
        let doc = Firestore.firestore().collection(ridersCollection).document(uid)

        doc.getDocument { [weak self] snap, _ in
            guard let self else { completion(); return }

            if let cid = snap?.data()?["stripeCustomerId"] as? String, !cid.isEmpty {
                print("✅ Stripe customer already provisioned:", cid)
                completion(); return
            }

            user.getIDToken { token, _ in
                var req = URLRequest(url: self.backendBase.appendingPathComponent("create-customer"))
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                // Optional: if you later secure the backend with Firebase Admin, send ID token:
                if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

                let body: [String: Any] = [
                    "email": user.email ?? "user-\(uid)@example.com",
                    "name":  user.displayName ?? "Rydr User",
                    "uid":   uid
                ]
                req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

                URLSession.shared.dataTask(with: req) { data, _, error in
                    if let error {
                        print("❌ /create-customer request failed:", error.localizedDescription)
                        completion(); return
                    }
                    guard
                        let data,
                        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                        let cid = json["customerId"] as? String
                    else {
                        print("❌ /create-customer invalid response")
                        completion(); return
                    }

                    // Save for quick access later (non-blocking)
                    doc.setData(["stripeCustomerId": cid, "updatedAt": FieldValue.serverTimestamp()],
                                merge: true) { err in
                        if let err {
                            print("⚠️ Failed to persist stripeCustomerId:", err.localizedDescription)
                        } else {
                            print("✅ Provisioned Stripe customer:", cid)
                        }
                        completion()
                    }
                }.resume()
            }
        }
    }

    // MARK: - Error/UI helper
    private func fail(_ message: String) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = message
        }
    }
}






