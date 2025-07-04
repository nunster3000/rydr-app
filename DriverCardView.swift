//
//  DriverCardView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/21/25.
//
import SwiftUI

struct Driver: Identifiable {
    let id: String
    let name: String
    let profileImage: String // Image name or URL
    let carImage: String     // Image name or URL
    let rating: Double       // 0 to 5
    let perMinute: Double
    let perMile: Double
    let driverScore: Double  // 0 to 100
}

struct DriverCardView: View {
    let driver: Driver
    let onConfirm: () -> Void

    private var totalEstimate: String {
        let est = (driver.perMinute * 10) + (driver.perMile * 5) + 5.0
        return String(format: "$%.2f", est)
    }

    private var scoreColor: Color {
        switch driver.driverScore {
        case 0..<50: return .red
        case 50..<75: return .yellow
        default: return .green
        }
    }

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .stroke(scoreColor, lineWidth: 5)
                    .frame(width: 100, height: 100)
                Image(driver.profileImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .frame(width: 90, height: 90)
            }

            Image(driver.carImage)
                .resizable()
                .scaledToFit()
                .frame(height: 80)
                .cornerRadius(10)

            Text(driver.name)
                .font(.headline)

            HStack(spacing: 3) {
                ForEach(0..<5) { index in
                    Image(systemName: index < Int(driver.rating) ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                }
                Text(String(format: "%.1f", driver.rating))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            VStack(spacing: 5) {
                Text("Rate: $\(String(format: "%.2f", driver.perMinute))/min · $\(String(format: "%.2f", driver.perMile))/mile")
                    .font(.subheadline)
                Text("Est. Cost: \(totalEstimate)")
                    .font(.title3)
                    .fontWeight(.bold)
            }

            Button("Confirm Ride") {
                onConfirm()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(scoreColor.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 10)
        .frame(width: 300)
    }
}

