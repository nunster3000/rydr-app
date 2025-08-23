//
//  AppDelegate.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/15/25.
//

import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseAppCheck
import Stripe

class AppDelegate: NSObject, UIApplicationDelegate {

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {

    // ✅ App Check provider MUST be set BEFORE FirebaseApp.configure()
    #if targetEnvironment(simulator)
    // Simulator: use Debug provider so Firestore works with enforcement ON
    AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
    print("🔐 AppCheck: Debug provider (simulator)")
    #else
    // Devices: prefer App Attest (iOS 14+), fallback to DeviceCheck
    if #available(iOS 14.0, *) {
      AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
      print("🔐 AppCheck: App Attest provider (device)")
    } else {
      AppCheck.setAppCheckProviderFactory(DeviceCheckProviderFactory())
      print("🔐 AppCheck: DeviceCheck provider (device)")
    }
    #endif

    // ✅ Firebase
    FirebaseApp.configure()

    // (Optional) Easier phone auth in DEBUG on simulator
    #if DEBUG
    Auth.auth().settings?.isAppVerificationDisabledForTesting = true
    #endif

    // ✅ Stripe publishable key (your provided test key)
    StripeAPI.defaultPublishableKey = "pk_test_51RcVGmBOkTOLtDHQgAvZmOvsvTxIqlcD3zLFgpkWD5pCQawjrFRBV3SjufrmGRb15GjVA7i351P1zfF7vbZ2J5gc00VuR0AYPc"
    print("💳 Stripe PK set")

    return true
  }

  // Firebase phone auth deep link handler
  func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    return Auth.auth().canHandle(url)
  }

  // Remote notifications passthrough (leave as-is)
  func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if Auth.auth().canHandleNotification(userInfo) {
      completionHandler(.noData)
      return
    }
    completionHandler(.noData)
  }
}





