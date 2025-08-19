//
//  TermsVerificationView.swift
//  RydrSignupFlow
//

// TermsAndVerificationView.swift

// TermsAndVerificationView.swift

import SwiftUI
import PhotosUI

struct TermsAndVerificationView: View {
    @Binding var termsAccepted: Bool
    @Binding var wantsVerification: Bool
    @Binding var idFront: PhotosPickerItem?
    @Binding var idBack: PhotosPickerItem?
    @Binding var selfie: PhotosPickerItem?
    var onSubmit: () -> Void

    @State private var showTermsModal = false
    @State private var showPrivacyModal = false
    @State private var showError = false

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                headerSection
                termsAgreementSection
                if showError && !termsAccepted {
                    Text("You must accept the Terms of Use and Privacy Policy to continue.")
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                }
                verificationToggleSection

                if wantsVerification {
                    uploadSection
                }

                Button("Create Account") {
                    if termsAccepted {
                        showError = false
                        onSubmit()
                    } else {
                        withAnimation {
                            showError = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.top)
            }
            .padding()
        }
        .sheet(isPresented: $showTermsModal) {
            TermsModalView()
        }
        .sheet(isPresented: $showPrivacyModal) {
            PrivacyModalView()
        }
    }
}

private extension TermsAndVerificationView {
    var headerSection: some View {
        Text("Almost Done!")
            .font(.title)
            .fontWeight(.bold)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.red, Color(red: 0.5, green: 0.0, blue: 0.13).opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }

    var termsAgreementSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("To proceed, you must agree to the Terms of Use and Privacy Policy.")
                .font(.footnote)
                .foregroundColor(.gray)

            Toggle(isOn: $termsAccepted) {
                Text("I agree to the Terms of Use and Privacy Policy")
                    .font(.subheadline)
            }
            .toggleStyle(SwitchToggleStyle(tint: .red))

            HStack(spacing: 4) {
                Button("View Terms of Use") {
                    showTermsModal = true
                }
                .font(.footnote)
                .foregroundColor(.blue)
                .underline()

                Text("|")
                    .font(.footnote)
                    .foregroundColor(.gray)

                Button("View Privacy Policy") {
                    showPrivacyModal = true
                }
                .font(.footnote)
                .foregroundColor(.blue)
                .underline()
            }
        }
    }

    var verificationToggleSection: some View {
        Toggle("Become a Verified Rider (optional)", isOn: $wantsVerification)
            .font(.subheadline)
            .toggleStyle(SwitchToggleStyle(tint: .red))
    }

    var uploadSection: some View {
        VStack(spacing: 15) {
            Text("Upload the following to be verified:")
                .font(.footnote)
                .foregroundColor(.gray)

            PhotosPicker(selection: $idFront, matching: .images) {
                UploadBox(label: "Upload State ID (Front)")
            }

            PhotosPicker(selection: $idBack, matching: .images) {
                UploadBox(label: "Upload State ID (Back)")
            }

            PhotosPicker(selection: $selfie, matching: .images) {
                UploadBox(label: "Upload Selfie")
            }
        }
    }
}



