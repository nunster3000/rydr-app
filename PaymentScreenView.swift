//
//  PaymentScreenView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/21/25.
//

import SwiftUI
import Stripe

struct PaymentScreenView: View {
    @State private var isPresentingPaymentSheet = false
    @State private var clientSecret: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("Loading…")
            } else {
                Button("Add Payment Method") {
                    fetchSetupIntent()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)

                if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
        .sheet(isPresented: $isPresentingPaymentSheet) {
            if let clientSecret = clientSecret {
                PaymentMethodView(clientSecret: clientSecret) { result in
                    switch result {
                    case .success(let successMessage):
                        print("Success: \(successMessage)")
                    case .failure(let error):
                        print("Failed with error: \(error.localizedDescription)")
                    }
                    isPresentingPaymentSheet = false
                }
            }
        }
    }

    func fetchSetupIntent() {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "https://stripe-backend.onrender.com/create-setup-intent") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // If needed, include a Stripe customer ID or Firebase Auth token here
        let body: [String: Any] = ["customerId": ""] // Replace this if needed
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }

                guard let data = data else {
                    errorMessage = "No data received"
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: String],
                       let secret = json["clientSecret"] {
                        self.clientSecret = secret
                        self.isPresentingPaymentSheet = true
                    } else {
                        errorMessage = "Invalid response from server"
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }.resume()
    }
}
