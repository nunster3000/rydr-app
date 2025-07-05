//
//  TermsofUseView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/14/25.
//
import SwiftUI

struct TermsModalView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Terms of Use")
                        .font(.title2)
                        .bold()

                    Text("""
                    Welcome to Rydr. By using our app, you agree to the following terms:

                    • Rydr connects riders with independent drivers. We are not liable for actions or behaviors of drivers or riders.

                    • Riders and drivers are responsible for their own compliance with local laws.

                    • Payment for rides must be made through approved methods.

                    • Any misconduct may result in suspension or termination of your account.

                    • By creating an account, you confirm you are at least 18 years of age.

                    These terms may be updated at any time.
                    """)
                }
                .padding()
            }
            .navigationTitle("Terms of Use")
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
    TermsModalView()
}


