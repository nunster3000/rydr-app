//
//  SignupCoordinator.swift
//  RydrSignupFlow
//
import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseAuth

enum SignupStep: Hashable {
    case nameEntry
    case emailPassword
    case addressEntry
    case paymentMethod
    case termsAndVerification
    case done
}

struct SignupCoordinator: View {
    @EnvironmentObject private var session: UserSessionManager

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
            // Your PhoneVerificationView should return a verified E.164 phone string
            PhoneVerificationView { verifiedPhone in
                phoneNumber = verifiedPhone
                upsertRider([
                    "phoneNumber": verifiedPhone,
                    "createdAt": FieldValue.serverTimestamp()
                ])
                path.append(.nameEntry)
            }
            .navigationDestination(for: SignupStep.self) { step in
                switch step {

                case .nameEntry:
                    NameEntryView(
                        firstName: $firstName,
                        lastName: $lastName,
                        preferredName: $preferredName,
                        onContinueWithForm: {
                            upsertRider([
                                "firstName": firstName,
                                "lastName": lastName,
                                "preferredName": preferredName
                            ])
                            path.append(.emailPassword)
                        },
                        onContinueWithSocial: {
                            upsertRider([
                                "firstName": firstName,
                                "lastName": lastName,
                                "preferredName": preferredName
                            ])
                            path.append(.addressEntry)
                        }
                    )

                case .emailPassword:
                    EmailAndPasswordView(
                        email: $email,
                        password: $password,
                        confirmPassword: $confirmPassword,
                        onNext: {
                            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                                if let error = error as NSError? {
                                    if error.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                                        // Dev‑friendly: continue flow and upsert email
                                        upsertRider(["email": email])
                                        path.append(.addressEntry)
                                    } else {
                                        print("❌ Firebase signup failed: \(error.localizedDescription)")
                                    }
                                    return
                                }
                                upsertRider([
                                    "uid": result?.user.uid ?? "",
                                    "email": email,
                                    "firstName": firstName,
                                    "lastName": lastName,
                                    "preferredName": preferredName,
                                    "phoneNumber": phoneNumber
                                ])
                                path.append(.addressEntry)
                            }
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
                            upsertRider([
                                "address": [
                                    "street": streetAddress,
                                    "line2": addressLine2,
                                    "city": city,
                                    "state": state,
                                    "zip": zip
                                ]
                            ])
                            path.append(.paymentMethod)
                        }
                    )

                case .paymentMethod:
                    PaymentScreenView(
                        onComplete: { path.append(.termsAndVerification) },
                        onSkip:     { path.append(.termsAndVerification) }   // ✅ optional
                    )

                case .termsAndVerification:
                    TermsAndVerificationView(
                        termsAccepted: $agreedToTerms,
                        wantsVerification: $isVerifiedUser,
                        idFront: $stateIDFront,
                        idBack: $stateIDBack,
                        selfie: $selfieImage,
                        onSubmit: {
                            saveUserToFirestore()
                        }
                    )

                case .done:
                    EmptyView()
                }
            }
        }
        .fullScreenCover(isPresented: $showMainApp) {
            MainTabView()
                .environmentObject(session)
        }
    }

    // MARK: - Firestore helpers

    /// Merge‑writes into `riders/{uid}` so the document exists early and stays current.
    private func upsertRider(_ fields: [String: Any]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore()
            .collection("riders").document(uid)
            .setData(fields, merge: true) { err in
                if let err = err { print("❌ upsertRider error: \(err)") }
            }
    }

    /// Final save (still uses merge so it’s idempotent), then load profile & go to app.
    private func saveUserToFirestore() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user to save.")
            return
        }

        let riderData: [String: Any] = [
            "uid": uid,
            "firstName": firstName,
            "lastName": lastName,
            "preferredName": preferredName,
            "email": email,
            "phoneNumber": phoneNumber,
            "address": [
                "street": streetAddress,
                "line2": addressLine2,
                "city": city,
                "state": state,
                "zip": zip
            ],
            "agreedToTerms": agreedToTerms,
            "verifiedUser": isVerifiedUser,
            "createdAt": FieldValue.serverTimestamp()
        ]

        Firestore.firestore()
            .collection("riders").document(uid)
            .setData(riderData, merge: true) { error in
                if let error = error {
                    print("❌ Error saving rider: \(error.localizedDescription)")
                } else {
                    print("✅ Rider saved to Firestore.")
                    // 🔁 Pull name/preferred so Profile greeting updates immediately
                    session.loadUserProfile()
                    showMainApp = true
                }
            }
    }
}





