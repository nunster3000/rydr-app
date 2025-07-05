//
//  NameEntryView.swift
//  RydrSignupFlow
//

import SwiftUI
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import FirebaseCore
import FirebaseFirestore

struct NameEntryView: View {
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var preferredName = ""
    @State private var errorMessage = ""
    @State private var isSaving = false

    var onContinueWithForm: () -> Void
    var onContinueWithSocial: () -> Void

    var body: some View {
        VStack(spacing: 25) {
            Text("Tell us your name")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red, Color(red: 0.5, green: 0, blue: 0.13).opacity(0.7)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )

            TextField("First Name", text: $firstName)
                .textFieldStyle(.roundedBorder)

            TextField("Last Name", text: $lastName)
                .textFieldStyle(.roundedBorder)

            TextField("Preferred Name (optional)", text: $preferredName)
                .textFieldStyle(.roundedBorder)

            Button(isSaving ? "Saving..." : "Continue") {
                saveUserToFirestore()
            }
            .disabled(isSaving)
            .buttonStyle(.borderedProminent)
            .tint(.red)

            Divider().padding(.vertical)

            // — Apple Sign Up button —
            SignInWithAppleButton(
                .signUp,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authResults):
                        handleAppleSignIn(result: authResults)
                    case .failure(let error):
                        errorMessage = "Apple sign‑up failed: \(error.localizedDescription)"
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 45)

            // — Google Sign Up button —
            Button(action: handleGoogleSignIn) {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .font(.title2)
                    Text("Sign Up with Google")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: — Firestore on submit
    private func saveUserToFirestore() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Unable to get user ID"
            return
        }

        isSaving = true
        errorMessage = ""

        let db = Firestore.firestore()
        let userData: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "preferredName": preferredName,
            "phoneNumber": Auth.auth().currentUser?.phoneNumber ?? "",
            "createdAt": Timestamp()
        ]

        db.collection("users").document(uid)
            .setData(userData) { error in
                isSaving = false
                if let error = error {
                    errorMessage = "Failed to save user: \(error.localizedDescription)"
                } else {
                    print("✅ User data saved to Firestore")
                    onContinueWithForm()
                }
            }
    }

    // MARK: — Google Sign-Up
    private func handleGoogleSignIn() {
        guard FirebaseApp.app()?.options.clientID != nil else {
            errorMessage = "Missing client ID"
            return
        }


        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to access root view controller"
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            if let error = error {
                errorMessage = "Google sign‑up failed: \(error.localizedDescription)"
                return
            }
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                errorMessage = "Google auth data missing"
                return
            }
            let accessToken = user.accessToken.tokenString
            let cred = GoogleAuthProvider.credential(withIDToken: idToken,
                                                     accessToken: accessToken)
            Auth.auth().signIn(with: cred) { authResult, err in
                if let err = err {
                    errorMessage = "Firebase Google auth failed: \(err.localizedDescription)"
                } else {
                    print("✅ Signed up with Google")
                    onContinueWithSocial()
                }
            }
        }
    }

    // MARK: — Apple Sign-Up
    private func handleAppleSignIn(result: ASAuthorization) {
        guard let appleCred = result.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleCred.identityToken,
              let tokenStr = String(data: identityToken, encoding: .utf8) else {
            errorMessage = "Apple credential or token missing"
            return
        }

        let oauth = OAuthProvider.credential(
            providerID: .apple,
            idToken: tokenStr,
            rawNonce: "" // 👉 production: generate a secure nonce
        )

        Auth.auth().signIn(with: oauth) { authResult, err in
            if let err = err {
                errorMessage = "Apple sign‑up failed: \(err.localizedDescription)"
            } else {
                print("✅ Signed up with Apple")
                onContinueWithSocial()
            }
        }
    }
}


