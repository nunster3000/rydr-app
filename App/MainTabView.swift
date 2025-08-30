//
//  MainTabView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/11/25.
//
import SwiftUI

struct MainTabView: View {
    @StateObject private var rideManager = RideManager()   // ✅ provide once here

    var body: some View {
        TabView {

            // Ride
            NavigationStack {
                RideTypeSelectionView()
            }
            .tabItem {
                Image(systemName: "car.fill")
                Text("Ride")
            }

            // Profile
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Image(systemName: "person.crop.circle")
                Text("Profile")
            }

            // RydrBank
            NavigationStack {
                RydrBankView()
            }
            .tabItem {
                Image(systemName: "banknote.fill")
                Text("RydrBank")
            }

            // Activity / History
            NavigationStack {
                RideHistoryView()                 // ✅ real view
                    .navigationTitle("Activity")
            }
            .tabItem {
                Image(systemName: "clock.arrow.circlepath")
                Text("Activity")
            }
        }
        .accentColor(.red)
        .environmentObject(rideManager)             // ✅ inject to all tabs
    }
}




