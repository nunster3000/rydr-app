//
//  PaymentScreenView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/21/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore



struct PaymentScreenView: View {
    @State private var showingPaymentSheet = false
    
    var body: some View {
        VStack {
            Button("Add Payment Method") {
                showingPaymentSheet = true
            }
        }
        .sheet(isPresented: $showingPaymentSheet) {
            PaymentMethodView(clientSecret: "your_client_secret_here") { paymentMethod in
                switch paymentMethod {
                case .success(let stripeId):
                    print("✅ Payment Method Created: \(stripeId)")
                    if let userId = Auth.auth().currentUser?.uid {
                        let db = Firestore.firestore()
                        db.collection("users").document(userId).setData([
                            "paymentMethodId": stripeId
                        ], merge: true)
                    }
                case .failure(let error):
                    print("❌ Failed to save card: \(error.localizedDescription)")
                }
            }
        }

        }
    }
