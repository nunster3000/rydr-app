//
//  PrivacyPolicy.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/14/25.
//
import SwiftUI

struct PrivacyModalView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Privacy Policy")
                        .font(.title2)
                        .bold()

                    Text("""
                    Your privacy matters. Here's what you need to know:

                    • We collect your name, phone number, email, address, and payment information to enable secure ride matching.

                    • Your personal data is never sold.

                    • Location data is used only to support ride logistics.

                    • We use encryption and secure authentication to protect your data.

                    • You may request deletion of your account at any time.

                    • We comply with all relevant privacy laws required by the Apple App Store and Google Play Store.

                    For full details, visit our website.
                    """)
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PrivacyModalView()
}


