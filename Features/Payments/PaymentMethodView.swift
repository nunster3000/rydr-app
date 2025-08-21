//
//  PaymentMethodView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/21/25.
//
import SwiftUI
import Stripe
import StripePaymentSheet

struct PaymentMethodView: View {
    // REQUIRED
    let clientSecret: String

    // OPTIONAL (customer-aware mode if provided)
    let customerId: String?
    let ephemeralKeySecret: String?

    // Completion callback
    let completion: (Result<String, Error>) -> Void

    @State private var paymentSheet: PaymentSheet?

    // ✅ Explicit initializer so your call with trailing closure compiles
    init(
        clientSecret: String,
        customerId: String? = nil,
        ephemeralKeySecret: String? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        self.clientSecret = clientSecret
        self.customerId = customerId
        self.ephemeralKeySecret = ephemeralKeySecret
        self.completion = completion
    }

    var body: some View {
        Color.clear.onAppear { prepareAndPresent() }
    }

    private func prepareAndPresent() {
        var config = PaymentSheet.Configuration()
        config.merchantDisplayName = "Rydr"

        if let cid = customerId,
           let ekey = ephemeralKeySecret,
           !cid.isEmpty, !ekey.isEmpty {
            config.customer = .init(id: cid, ephemeralKeySecret: ekey)
        }

        self.paymentSheet = PaymentSheet(
            setupIntentClientSecret: clientSecret,
            configuration: config
        )
        present()
    }

    private func present() {
        guard
            let paymentSheet = paymentSheet,
            let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
            let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }

        var top = root
        while let presented = top.presentedViewController { top = presented }

        paymentSheet.present(from: top) { result in
            switch result {
            case .completed:
                completion(.success("Payment method added"))
            case .canceled:
                completion(.failure(NSError(domain: "UserCanceled", code: 0)))
            case .failed(let error):
                completion(.failure(error))
            }
        }
    }
}


