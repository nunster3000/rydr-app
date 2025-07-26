//
//  PaymentMethodView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/21/25.
//
import SwiftUI
import StripePaymentSheet
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct PaymentMethodView: View {
    let clientSecret: String
    var completion: (Result<String, Error>) -> Void

    @State private var paymentSheet: PaymentSheet?

    var body: some View {
        VStack {
            Text("Add a Payment Method")
            Button("Add Card") {
                presentPaymentSheet(completion: completion)
            }
        }
        .onAppear {
            loadStripeCustomerId { existingCustomerId in
                if let customerId = existingCustomerId {
                    print("Found Stripe customer ID: \(customerId)")
                    createSetupIntent(customerId: customerId)
                } else {
                    guard let user = Auth.auth().currentUser else {
                        print("User not logged in")
                        return
                    }

                    let email = user.email ?? "noemail@example.com"
                    let uid = user.uid

                    createStripeCustomer(email: email, uid: uid) { newCustomerId in
                        if let newId = newCustomerId {
                            print("Created new Stripe customer ID: \(newId)")
                            let db = Firestore.firestore()
                            db.collection("users").document(uid).setData([
                                "stripeCustomerId": newId
                            ], merge: true)
                            createSetupIntent(customerId: newId)
                        } else {
                            print("Failed to create Stripe customer.")
                        }
                    }
                }
            }
        }
    }

    private func loadPaymentSheet() {
        guard let user = Auth.auth().currentUser else {
            print("User not logged in.")
            return
        }

        let uid = user.uid
        let email = user.email ?? "noemail@example.com"
        let db = Firestore.firestore()

        db.collection("users").document(uid).getDocument { docSnapshot, error in
            if let error = error {
                print("Firestore error: \(error.localizedDescription)")
                return
            }

            let existingCustomerId = docSnapshot?.data()?["stripeCustomerId"] as? String

            if let customerId = existingCustomerId {
                print("Found existing Stripe customer ID: \(customerId)")
                createSetupIntent(customerId: customerId)
            } else {
                print("No Stripe customer ID found. Creating new one...")
                createStripeCustomer(email: email, uid: uid) { newCustomerId in
                    if let newId = newCustomerId {
                        db.collection("users").document(uid).setData([
                            "stripeCustomerId": newId
                        ], merge: true)
                        print("Saved new customer ID to Firestore.")
                        createSetupIntent(customerId: newId)
                    } else {
                        print("Failed to create Stripe customer.")
                    }
                }
            }
        }
    }

    private func createStripeCustomer(email: String, uid: String = UUID().uuidString, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://rydr-stripe-backend.onrender.com/create-customer") else {
            print("Invalid URL")
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["email": email, "uid": uid]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Error encoding JSON body: \(error)")
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data else {
                print("No data received")
                completion(nil)
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let customerId = json["customerId"] as? String {
                    print("Created Stripe customer: \(customerId)")
                    completion(customerId)
                } else {
                    print("Invalid JSON response")
                    completion(nil)
                }
            } catch {
                print("JSON decoding error: \(error)")
                completion(nil)
            }
        }.resume()
    }

    private func loadStripeCustomerId(completion: @escaping (String?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            print("User not logged in")
            completion(nil)
            return
        }

        let uid = user.uid
        let db = Firestore.firestore()

        db.collection("users").document(uid).getDocument { docSnapshot, error in
            if let error = error {
                print("Firestore error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            if let data = docSnapshot?.data(),
               let stripeCustomerId = data["stripeCustomerId"] as? String {
                print("Found existing Stripe customer ID: \(stripeCustomerId)")
                completion(stripeCustomerId)
            } else {
                print("No Stripe customer ID found.")
                completion(nil)
            }
        }
    }

    private func createSetupIntent(customerId: String) {
        guard let url = URL(string: "https://rydr-stripe-backend.onrender.com/create-setup-intent") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["customerId": customerId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                completion(.failure(NSError(domain: "SetupIntentError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error or invalid data"])))
                return
            }

            guard let data = data else {
                print("No data received")
                completion(.failure(NSError(domain: "SetupIntentError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error or invalid data"])))
                return
            }

            if let rawString = String(data: data, encoding: .utf8) {
                print("Raw response: \(rawString)")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let clientSecret = json["clientSecret"] as? String else {
                print("JSON decode failed or missing clientSecret")
                completion(.failure(NSError(domain: "SetupIntentError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])))
                return
            }

            print("Got client secret: \(clientSecret)")
            DispatchQueue.main.async {
                var configuration = PaymentSheet.Configuration()
                configuration.merchantDisplayName = "Rydr"
                self.paymentSheet = PaymentSheet(
                    setupIntentClientSecret: clientSecret,
                    configuration: configuration
                )
            }
        }.resume()
    }

    private func presentPaymentSheet(completion: @escaping (Result<String, Error>) -> Void) {
        guard let paymentSheet = paymentSheet,
              let topController = UIApplication.shared.connectedScenes
                  .compactMap({ $0 as? UIWindowScene })
                  .flatMap({ $0.windows })
                  .first(where: { $0.isKeyWindow })?
                  .rootViewController else {
            print("Failed to get payment sheet or top view controller")
            return
        }

        paymentSheet.present(from: topController) { result in
            switch result {
            case .completed:
                print("Payment method added")
                completion(.success("Payment method added"))
            case .canceled:
                print("Payment canceled")
                completion(.failure(NSError(domain: "UserCanceled", code: 0)))
            case .failed(let error):
                print("Payment failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Helper Extension
import UIKit

extension UIApplication {
    func topViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}
