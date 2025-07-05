//
//  PhoneVerificationView.swift
//  RydrSignupFlow
//

import SwiftUI
import FirebaseAuth

struct PhoneVerificationView: View {
    @Binding var phoneNumber: String
    var onComplete: () -> Void

    @State private var verificationCode: String = ""
    @State private var codeSent = false
    @State private var errorMessage = ""
    @State private var rawPhoneNumber = ""
    @State private var goToNameEntry = false

    var body: some View {
        VStack(spacing: 30) {
            Text("Create Your Rydr Account")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.red, Color(red: 0.5, green: 0, blue: 0.13).opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            HStack {
                Image(systemName: "flag.fill")
                TextField("Phone Number", text: Binding(
                    get: { formatPhoneNumber(rawPhoneNumber) },
                    set: { newValue in
                        rawPhoneNumber = newValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                        phoneNumber = "+1" + rawPhoneNumber
                    }
                ))
                .keyboardType(.numberPad)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        LinearGradient(
                            colors: [.red, Color(red: 0.5, green: 0, blue: 0.13).opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .padding(.horizontal)

            if !codeSent {
                Button("Send Verification Code") {
                    let fullNumber = "+1" + rawPhoneNumber
                    phoneNumber = fullNumber

                    if isValidPhoneNumber(fullNumber) {
                        errorMessage = ""
                        PhoneAuthProvider.provider().verifyPhoneNumber(fullNumber, uiDelegate: nil) { verificationID, error in
                            if let error = error {
                                errorMessage = error.localizedDescription
                                return
                            }
                            if let verificationID = verificationID {
                                UserDefaults.standard.set(verificationID, forKey: "authVerificationID")
                                codeSent = true
                            }
                        }
                    } else {
                        errorMessage = "Please enter a valid U.S. phone number"
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }

            if codeSent {
                VStack(spacing: 16) {
                    TextField("Enter Verification Code", text: $verificationCode)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)

                    Button("Verify & Continue") {
                        guard let verificationID = UserDefaults.standard.string(forKey: "authVerificationID") else {
                            errorMessage = "Verification failed. Try again."
                            return
                        }

                        let credential = PhoneAuthProvider.provider().credential(
                            withVerificationID: verificationID,
                            verificationCode: verificationCode
                        )

                        Auth.auth().signIn(with: credential) { authResult, error in
                            if let error = error {
                                errorMessage = error.localizedDescription
                                return
                            }

                            print("✅ Signed in user: \(authResult?.user.uid ?? "")")
                            goToNameEntry = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding(.horizontal)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
        .onChange(of: goToNameEntry) {
            if goToNameEntry {
                onComplete()
            }
        }
    }

    // Format phone number for UI
    private func formatPhoneNumber(_ number: String) -> String {
        let cleanNumber = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let mask = "(XXX) XXX-XXXX"
        var result = ""
        var index = cleanNumber.startIndex

        for ch in mask where index < cleanNumber.endIndex {
            if ch == "X" {
                result.append(cleanNumber[index])
                index = cleanNumber.index(after: index)
            } else {
                result.append(ch)
            }
        }

        return result
    }

    // Validate format like +1XXXXXXXXXX
    private func isValidPhoneNumber(_ number: String) -> Bool {
        let cleaned = number.replacingOccurrences(of: "[^\\+\\d]", with: "", options: .regularExpression)
        let pattern = #"^\+1\d{10}$"#
        return cleaned.range(of: pattern, options: .regularExpression) != nil
    }
}

