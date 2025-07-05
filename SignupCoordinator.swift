//
//  SignupCoordinator.swift
//  RydrSignupFlow
//

import SwiftUI
import PhotosUI

enum SignupStep: Hashable {
    case nameEntry
    case emailPassword
    case addressEntry
    case paymentMethod
    case termsAndVerification
    case done
}

struct SignupCoordinator: View {
    @State private var path: [SignupStep] = []

    // Shared user data across steps
    @State private var phoneNumber = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var preferredName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword: String = ""
    @State private var streetAddress = ""
    @State private var addressLine2 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    @State private var agreedToTerms = false
    @State private var isVerifiedUser = false
    @State private var stateIDFront: PhotosPickerItem?
    @State private var stateIDBack: PhotosPickerItem?
    @State private var selfieImage: PhotosPickerItem?

    // Navigate to main app
    @State private var showMainApp = false

    var body: some View {
        NavigationStack(path: $path) {
            PhoneVerificationView(
                phoneNumber: $phoneNumber,
                onComplete: {
                    path.append(.nameEntry)
                }
            )
            .navigationDestination(for: SignupStep.self) { step in
                switch step {
                case .nameEntry:
                    NameEntryView(
                        onContinueWithForm: {
                            path.append(.emailPassword)
                        },
                        onContinueWithSocial: {
                            path.append(.addressEntry)
                        }
                    )

                case .emailPassword:
                    EmailAndPasswordView(
                        email: $email,
                        password: $password,
                        confirmPassword: $confirmPassword,
                        onNext: {
                            path.append(.addressEntry)
                        }
                    )

                case .addressEntry:
                    AddressInfoView(
                        street: $streetAddress,
                        addressLine2: $addressLine2,
                        city: $city,
                        state: $state,
                        zipCode: $zip,
                        onNext: {
                            path.append(.paymentMethod) // 👈 Now goes to payment step
                        }
                    )

                case .paymentMethod:
                    // Placeholder view — replace with actual PaymentView later
                    Text("💳 Payment Method View Coming Soon")

                case .termsAndVerification:
                    TermsAndVerificationView(
                        termsAccepted: $agreedToTerms,
                        wantsVerification: $isVerifiedUser,
                        idFront: $stateIDFront,
                        idBack: $stateIDBack,
                        selfie: $selfieImage,
                        onSubmit: {
                            path.append(.done)
                        }
                    )

                case .done:
                    // Optional: You could navigate here or trigger the main app switch
                    EmptyView()
                }
            }

        }
        .fullScreenCover(isPresented: $showMainApp) {
            MainTabView()
        }
    }
}

