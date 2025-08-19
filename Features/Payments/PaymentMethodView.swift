//
//  PaymentMethodView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/21/25.
//
import SwiftUI
import Stripe
import StripePaymentSheet
import Firebase
import FirebaseAuth

struct PaymentMethodView: View {
    let clientSecret: String
    var completion: (Result<String, Error>) -> Void

    @State private var paymentSheet: PaymentSheet?

    var body: some View {
        Text("Presenting Payment Sheet...") // Optional placeholder
            .onAppear {
                var config = PaymentSheet.Configuration()
                config.merchantDisplayName = "Rydr"

                self.paymentSheet = PaymentSheet(
                    setupIntentClientSecret: clientSecret,
                    configuration: config
                )

                presentPaymentSheet()
            }
    }

    private func presentPaymentSheet() {
        guard let paymentSheet = paymentSheet,
              let topVC = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow })?
                .rootViewController else {
            print("❌ Failed to access root view controller")
            return
        }

        paymentSheet.present(from: topVC) { result in
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
}
