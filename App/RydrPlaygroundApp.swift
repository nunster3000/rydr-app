//
//  RydrPlaygroundApp.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/11/25.
//

import SwiftUI
import Firebase
import Stripe

@main
struct RydrApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var session = UserSessionManager()
    @State private var showSplash = true

    init() {
        // ✅ Stripe publishable key configuration
        #if DEBUG
        // Use your TEST key while developing
        StripeAPI.defaultPublishableKey = "pk_live_51RcVGmBOkTOLtDHQ0NUCnyxYUwNOCjIiBH26h680td6HGxKzcMqbABcDSySpekisDaNCoMdnotMBfsLB9qJQJA9K00xsVu4KtR"
        print("🔐 Using DEBUG Stripe test key")
        #else
        // In Release, require the key to come from Info.plist
        if let pk = Bundle.main.object(forInfoDictionaryKey: "STRIPE_PUBLISHABLE_KEY") as? String,
           !pk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            StripeAPI.defaultPublishableKey = pk
            print("🔐 Loaded Stripe key from Info.plist")
        } else {
            assertionFailure("Missing STRIPE_PUBLISHABLE_KEY in Info.plist for Release builds.")
            // Optional: you can early-return or set an empty key to crash fast on first Stripe call
            StripeAPI.defaultPublishableKey = ""
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashVideoView { showSplash = false }
            } else {
                if session.isLoggedIn {
                    MainTabView().environmentObject(session)
                } else {
                    WelcomeView().environmentObject(session)
                }
            }
        }
    }
}





