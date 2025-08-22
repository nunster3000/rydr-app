//
//  WelcomeView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/14/25.
//
import SwiftUI

struct WelcomeView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {

                // Logo
                Image("RydrLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
                    .padding(.top, 50)

                Text("Ride with Rydr")
                    .font(.largeTitle)
                    .bold()
                    .padding(.horizontal)

                // Login Button
                NavigationLink(destination: LoginView()) {
                    Text("Log In")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle())

                // Sign Up Button
                NavigationLink(destination: SignupCoordinator()) {
                    Text("Sign Up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle())


                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(UserSessionManager())
}


