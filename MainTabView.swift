//
//  MainTabView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/11/25.
//
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                RideTypeSelectionView() // Shows ride options like Rydr Go, XL, etc.
            }
            .tabItem {
                Image(systemName: "car.fill")
                Text("Ride")
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Image(systemName: "person.crop.circle")
                Text("Profile")
            }

            NavigationStack {
                RydrBankView()
            }
            .tabItem {
                Image(systemName: "banknote.fill")
                Text("RydrBank")
            }

            NavigationStack {
                RideHistoryView()
            }
            .tabItem {
                Image(systemName: "clock.arrow.circlepath")
                Text("Activity")
            }
        }

        .accentColor(.red) // Optional: make tab icon/text red when selected
    }
}

// MARK: - Placeholder Views for Screens
struct RydrBankView: View {
    var body: some View {
        Text("Welcome to RydrBank")
            .font(.title)
    }
}

struct RideHistoryView: View {
    var body: some View {
        Text("Your Ride History")
            .font(.title)
    }
}

// MARK: - Preview
#Preview {
    MainTabView()
        .environmentObject(UserSessionManager())
}


