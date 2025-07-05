//
//  Untitled.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/14/25.
//
import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @EnvironmentObject var session: UserSessionManager
    
    @State private var isUsingEmail = false
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showLogo = false
    @State private var errorMessage = ""
    @State private var showPasswordResetAlert = false
    
    var body: some View {
        VStack(spacing: 25) {
            Image("RydrLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .opacity(showLogo ? 1 : 0)
                .animation(.easeIn(duration: 1.0), value: showLogo)
                .onAppear { showLogo = true }
                .padding(.top)
                .accessibilityLabel("Rydr logo")
            
            Text("Hello There!")
                .font(.title)
                .foregroundStyle(Styles.rydrGradient)
            
            // MARK: - Phone Login
            if !isUsingEmail {
                TextField("Enter your phone number", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Phone Number Field")
                
                Button("Send Code") {
                    // TODO: Trigger Firebase OTP
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Styles.rydrGradient)
                .foregroundColor(.white)
                .cornerRadius(10)
                .accessibilityLabel("Send Verification Code")
                
                Button("Use email and password instead") {
                    withAnimation { isUsingEmail = true }
                }
                .font(.caption)
                .accessibilityLabel("Switch to email and password login")
            }
            
            // MARK: - Email Login
            if isUsingEmail {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .accessibilityLabel("Email Field")
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Password Field")
                
                Button("Log In with Email") {
                    // TODO: Firebase email login
                    session.login(name: "Rydr User", email: email)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Styles.rydrGradient)
                .foregroundColor(.white)
                .cornerRadius(10)
                .accessibilityLabel("Login with Email")
                
                Button("Forgot Password?") {
                    sendPasswordReset()
                }
                .font(.caption)
                .foregroundColor(.blue)
                .accessibilityLabel("Reset password via email")
                
                Button("Use phone number instead") {
                    withAnimation { isUsingEmail = false }
                }
                .font(.caption)
                .accessibilityLabel("Switch to phone login")
            }
            
            Divider().padding(.vertical)
            
            // MARK: - Apple & Google Sign-In
            Button(action: {
                // TODO: Handle Apple Sign-In
            }) {
                Label("Sign in with Apple", systemImage: "apple.logo")
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(10)
            .accessibilityLabel("Sign in with Apple")
            
            Button(action: {
                // TODO: Handle Google Sign-In
            }) {
                Label("Sign in with Google", systemImage: "globe")
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color.white)
            .foregroundColor(.black)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
            )
            .accessibilityLabel("Sign in with Google")
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Spacer()
        }
        .padding()
        .hideKeyboardOnTap()
        .alert(isPresented: $showPasswordResetAlert) {
            Alert(
                title: Text("Reset Email Sent"),
                message: Text("Check your inbox at \(email) for a link to reset your password."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Password Reset
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx =
        "(?:[A-Z0-9a-z._%+-]+)@(?:[A-Z0-9a-z.-]+)\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return predicate.evaluate(with: email)
    }
    
    private func sendPasswordReset() {
        // Simple email format validation
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address."
            return
        }
        
        // Firebase password reset
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error as NSError?,
               let errorCode = AuthErrorCode(rawValue: error.code) {
                switch errorCode {
                case .userNotFound:
                    errorMessage = "No account found with this email."
                case .invalidRecipientEmail:
                    errorMessage = "The reset email address is invalid."
                case .invalidSender:
                    errorMessage = "Invalid email sender. Please contact support."
                default:
                    errorMessage = "Reset failed: \(error.localizedDescription)"
                }
            } else {
                errorMessage = ""
                showPasswordResetAlert = true
            }
            
        }
    }
}





