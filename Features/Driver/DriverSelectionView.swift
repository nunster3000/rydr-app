//
//  DriverSelectionView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/21/25.
//
import SwiftUI

struct DriverSelectionView: View {
    let drivers: [Driver]
    var onConfirm: (Driver) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                    .padding()
                }
                Spacer()
            }

            TabView {
                ForEach(drivers) { driver in
                    DriverCardView(driver: driver) {
                        onConfirm(driver)
                        dismiss()
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .frame(height: 500)
            .padding(.top)
        }
    }
}
