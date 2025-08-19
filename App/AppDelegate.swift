//
//  AppDelegate.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/15/25.
import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseAppCheck

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()

        // ✅ Make Firebase Phone Auth work on the iOS simulator (dev-only)
        #if DEBUG
        Auth.auth().settings?.isAppVerificationDisabledForTesting = true
        #endif

        return true
    }

    // Handle Firebase phone verification links (deep links)
    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return Auth.auth().canHandle(url)
    }

    // Handle Firebase-related remote notifications
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        completionHandler(.noData)
    }
}




