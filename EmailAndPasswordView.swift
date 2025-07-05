//
//  EmailPasswordView.swift
//  RydrSignupFlow
//

import SwiftUI

struct EmailAndPasswordView: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    var onNext: () -> Void

    @State private var passwordValidations: [String: Bool] = [
        "At least 8 characters": false,
        "1 uppercase letter": false,
        "1 number": false,
        "1 special character": false
    ]

    private var allValid: Bool {
        passwordValidations.values.allSatisfy { $0 } && !confirmPassword.isEmpty && password == confirmPassword
    }

    var body: some View {
        VStack(spacing: 25) {
            // Header & Email Field
            Text("Set Up Your Login")
                .font(.title).bold()
                .foregroundStyle(LinearGradient(
                    colors: [Color.red, Color(red: 0.5, green: 0, blue: 0.13).opacity(0.7)],
                    startPoint: .leading, endPoint: .trailing
                ))

            HStack {
                Image(systemName: "envelope").foregroundColor(.gray)
                TextField("Email Address", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            .inputFieldStyle()

            // Password Field
            HStack {
                Image(systemName: "lock").foregroundColor(.gray)
                SecureField("Create Password", text: $password)
                    .onChange(of: password) {
                        validatePassword(password)
                    }
            }
            .inputFieldStyle()

            // Password Rules – always displayed
            VStack(alignment: .leading, spacing: 6) {
                ForEach(passwordValidations.sorted(by: { $0.key < $1.key }), id: \.key) { rule, passed in
                    HStack {
                        Image(systemName: passed ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(passed ? .green : .gray)
                        Text(rule).font(.caption)
                    }
                }
            }.padding(.horizontal)

            // Confirm Password Field
            HStack {
                Image(systemName: "lock.rotation").foregroundColor(.gray)
                SecureField("Confirm Password", text: $confirmPassword)
            }
            .inputFieldStyle()

            // Password match feedback
            if !confirmPassword.isEmpty && password != confirmPassword {
                Text("Passwords do not match.")
                    .foregroundColor(.red)
                    .font(.caption)
                    .transition(.opacity)
            }

            // Continue Button
            Button("Continue") {
                onNext()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(!allValid)

            Spacer()
        }
        .padding()
    }

    private func validatePassword(_ text: String) {
        passwordValidations["At least 8 characters"] = text.count >= 8
        passwordValidations["1 uppercase letter"] = text.rangeOfCharacter(from: .uppercaseLetters) != nil
        passwordValidations["1 number"] = text.rangeOfCharacter(from: .decimalDigits) != nil
        passwordValidations["1 special character"] = text.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+{}|:<>?-=[];,./")) != nil
    }
}


