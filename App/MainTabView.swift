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

            // RydrBank (uses your real view from its own file)
            NavigationStack {
                RydrBankView()
            }
            .tabItem {
                Image(systemName: "banknote.fill")
                Text("RydrBank")
            }

            // Activity / History (keep the icon, unique placeholder name)
            NavigationStack {
                RideHistoryShortcutView()
                    .navigationTitle("Activity")
            }
            .tabItem {
                Image(systemName: "clock.arrow.circlepath")
                Text("Activity")
            }
        }
        .accentColor(.red)
    }
}

// MARK: - Unique placeholder (keeps your “Activity” shortcut)
struct RideHistoryShortcutView: View {
    var body: some View {
        Text("Your Ride History (coming soon)")
            .font(.title)
            .padding()
    }
}

#Preview {
    MainTabView()
        .environmentObject(UserSessionManager())
}



