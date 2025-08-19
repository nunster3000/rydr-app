//
//  PhoneVerificationView.swift
//  RydrSignupFlow
//
import SwiftUI
import FirebaseAuth

struct PhoneVerificationView: View {
    var onVerified: (String) -> Void

    // Country selection
    @State private var selectedCountry: Country = .us
    @State private var nationalNumber: String = ""

    @State private var sending = false
    @State private var errorMessage = ""
    @State private var verificationID: String?
    @State private var goToCode = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Enter your phone").font(.title).bold()

            // Phone input row: [country selector][national number]
            HStack(spacing: 10) {
                Menu {
                    ForEach(Country.all, id: \.self) { c in
                        Button {
                            selectedCountry = c
                        } label: {
                            Label("\(c.flag) \(c.name) \(c.dialCode)", systemImage: "")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedCountry.flag)
                        Text(selectedCountry.dialCode)
                            .font(.body.weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                TextField("Phone number", text: $nationalNumber)
                    .keyboardType(.phonePad)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .onChange(of: nationalNumber) { oldValue, newValue in
                        // keep only digits in the national part
                        nationalNumber = newValue.filter { $0.isNumber }
                    }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage).foregroundColor(.red).font(.footnote)
            }

            Button {
                sendCode()
            } label: {
                Text(sending ? "Sending..." : "Send Code")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(sending ? Color.gray : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(sending || nationalNumber.isEmpty)

            Spacer()
        }
        .padding()
        .navigationDestination(isPresented: $goToCode) {
            let e164 = fullE164()
            VerificationCodeView(
                verificationID: verificationID ?? "",
                phoneNumber: e164,
                onSuccess: { onVerified(e164) },
                onResendCode: { sendCode(resend: true) }
            )
        }
    }

    private func fullE164() -> String {
        selectedCountry.dialCode + nationalNumber   // e.g. +1 + 4045551234
    }

    private func sendCode(resend: Bool = false) {
        errorMessage = ""
        sending = true
        let e164 = fullE164()

        // DEBUG/testing on simulator (don’t ship enabled):
        // Auth.auth().settings?.isAppVerificationDisabledForTesting = true

        PhoneAuthProvider.provider().verifyPhoneNumber(e164, uiDelegate: nil) { id, error in
            sending = false
            if let error = error {
                errorMessage = "Failed to send code: \(error.localizedDescription)"
                return
            }
            verificationID = id
            goToCode = true
        }
    }
}

// MARK: - Country model (minimal set; add more as needed)
private struct Country: Hashable {
    let name: String
    let code: String      // ISO
    let dialCode: String  // e.g. "+1"
    let flag: String

    static let us = Country(name: "United States", code: "US", dialCode: "+1", flag: "🇺🇸")
    static let ca = Country(name: "Canada",        code: "CA", dialCode: "+1", flag: "🇨🇦")
    static let mx = Country(name: "Mexico",        code: "MX", dialCode: "+52", flag: "🇲🇽")

    static let all: [Country] = [.us, .ca, .mx]
}





