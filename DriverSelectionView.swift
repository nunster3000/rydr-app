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

    var body: some View {
        TabView {
            ForEach(drivers) { driver in
                DriverCardView(driver: driver) {
                    onConfirm(driver)
                }
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
        .frame(height: 500)
        .padding(.top)
    }
}
