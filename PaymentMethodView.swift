//
//  PaymentMethodView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/21/25.
//
import SwiftUI
import StripePaymentSheet

struct PaymentMethodView: View {
    var clientSecret: String
    var onComplete: (Result<String, Error>) -> Void

    @State private var paymentSheet: PaymentSheet?

    var body: some View {
        VStack {
            Button("Add Payment Method") {
                preparePaymentSheet()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
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

        presentPaymentSheet()
    }

    private func presentPaymentSheet() {
        guard let paymentSheet = paymentSheet,
              let topController = UIApplication.shared.topViewController() else {
            print("❌ Failed to get payment sheet or top view controller")
            return
        }

        paymentSheet.present(from: topController) { result in
            switch result {
            case .completed:
                print("✅ Payment method added")
                onComplete(.success("Payment method added"))
            case .canceled:
                print("❌ Payment canceled")
                onComplete(.failure(NSError(domain: "UserCanceled", code: 0)))
            case .failed(let error):
                print("❌ Payment failed: \(error.localizedDescription)")
                onComplete(.failure(error))
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
