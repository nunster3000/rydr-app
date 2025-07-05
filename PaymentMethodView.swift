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
            // ✅ 1. Grab the user's email (replace with real logic if needed)
                let email = Auth.auth().currentUser?.email ?? "testuser@example.com"
                
                // ✅ 2. Call the function to create the Stripe customer
                createStripeCustomer(email: email) { customerId in
                    if let id = customerId {
                        print("🔵 Stripe Customer ID: \(id)")
                        
                        // ⬇️ You may choose to store this in Firebase or @State
                        // For now, you can also use it immediately in SetupIntent creation
                    } else {
                        print("❌ Failed to create Stripe customer.")
                    }
                }
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "Rydr"
            
            paymentSheet = PaymentSheet(
                setupIntentClientSecret: clientSecret,
                configuration: configuration
            )
        }
    }
    private func fetchStripeCustomerIdAndPrepareSheet() {
           guard let user = Auth.auth().currentUser else {
               print("❌ User not authenticated")
               return
           }
           
           let uid = user.uid
           let db = Firestore.firestore()
           
           db.collection("users").document(uid).getDocument { docSnapshot, error in
               if let doc = docSnapshot, let data = doc.data(),
                  let stripeCustomerId = data["stripeCustomerId"] as? String {
                   print("✅ Got Stripe customerId: \(stripeCustomerId)")
                   self.createSetupIntent(customerId: stripeCustomerId)
               } else {
                   print("❌ Could not retrieve stripeCustomerId")
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
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(NSError(domain: "SetupIntentError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error or invalid data"])))
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                completion(.failure(NSError(domain: "SetupIntentError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error or invalid data"])))
                return
            }
            
            // ✅ Debug the raw response
            if let rawString = String(data: data, encoding: .utf8) {
                print("🧾 Raw response: \(rawString)")
            }
            
            // Try to decode as JSON
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let clientSecret = json["clientSecret"] as? String else {
                print("❌ JSON decode failed or missing clientSecret")
                completion(.failure(NSError(domain: "SetupIntentError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error or invalid data"])))
                return
            }
            
            print("✅ Got client secret: \(clientSecret)")
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
    
    
    private func preparePaymentSheet() {
        var config = PaymentSheet.Configuration()
        config.merchantDisplayName = "Rydr"
        // Add Apple Pay or custom config if needed

        print("🧾 Client Secret: \(clientSecret)")

        paymentSheet = PaymentSheet(
            setupIntentClientSecret: clientSecret,
            configuration: config
        )

        presentPaymentSheet { result in
            switch result {
            case .success(let message):
                print("✅ \(message)")
            case .failure(let error):
                print("❌ Error: \(error.localizedDescription)")
            }
        }
    }


    private func presentPaymentSheet(completion: @escaping (Result<String, Error>) -> Void) {
        guard let paymentSheet = paymentSheet,
              let topController = UIApplication.shared.connectedScenes
                  .compactMap({ $0 as? UIWindowScene })
                  .flatMap({ $0.windows })
                  .first(where: { $0.isKeyWindow })?
                  .rootViewController else {
            print("❌ Failed to get payment sheet or top view controller")
            return
        }

        paymentSheet.present(from: topController) { result in
            switch result {
            case .completed:
                print("✅ Payment method added")
                completion(.success("Payment method added"))
            case .canceled:
                print("❌ Payment canceled")
                completion(.failure(NSError(domain: "UserCanceled", code: 0)))
            case .failed(let error):
                print("❌ Payment failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    func createStripeCustomer(email: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://rydr-stripe-backend.onrender.com/create-customer") else {
            print("Invalid URL")
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ["email": email]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let customerId = json["customerId"] as? String else {
                print("Invalid response")
                completion(nil)
                return
            }

            print("Stripe customer ID: \(customerId)")
            completion(customerId)
        }.resume()
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
