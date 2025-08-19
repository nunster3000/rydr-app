//
//  SafeRydrView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 7/27/25.
//


import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SafeRydrView: View {
    @State private var showConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Image(systemName: "shield.lefthalf.filled")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.red)

                Text("SafeRydr Mode")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Coming Soon")
                    .font(.title2)
                    .foregroundColor(.gray)

                VStack(alignment: .leading, spacing: 15) {
                    Text("Safer Rides. Built Around You.")
                        .font(.headline)

                    Text("""
SafeRydr is a premium safety feature designed for riders who want consistency, trust, and peace of mind in their daily routines.

- ✅ Dashcam-equipped rides for greater transparency
- ✅ Hand-pick your preferred driver for regular trips
- ✅ Plan weekly rides in advance with flexible scheduling

Whether it’s school drop-offs, regular appointments, or recurring errands — SafeRydr is here to give families and individuals the confidence to ride safer.

This feature does **not** currently support services like shopping or medication pickup.
""")
                }
                .padding()

                // 🔘 "I’m Interested" Button
                Button(action: registerInterest) {
                    Text("I’m Interested")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                // ✅ Confirmation Message
                if showConfirmation {
                    Text("✅ You’ll be notified when SafeRydr becomes available.")
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if let errorMessage = errorMessage {
                    Text("⚠️ \(errorMessage)")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Text("SafeRydr will be launching soon to select riders. Stay tuned for early access opportunities.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle("SafeRydr")
        }
    }

    // 🔧 Save interest to Firestore
    private func registerInterest() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Please log in to register interest."
            return
        }

        let db = Firestore.firestore()
        let interestRef = db.collection("safeRydrInterest").document(user.uid)

        interestRef.setData([
            "uid": user.uid,
            "email": user.email ?? "unknown",
            "timestamp": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                self.errorMessage = "Error saving interest: \(error.localizedDescription)"
            } else {
                self.errorMessage = nil
                self.showConfirmation = true
            }
        }
    }
}

