//
//  DriverSelectionView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/21/25.
//
import SwiftUI
import MapKit

struct DriverSelectionView: View {
    @ObservedObject var rideManager: RideManager

    let rideType: String          // "Rydr Go" / "Rydr XL" / "Rydr Prestine"
    let pickup: String
    let dropoff: String
    let region: MKCoordinateRegion
    let onAccepted: () -> Void    // host should open In-Progress
    let onClose: () -> Void

    @State private var pageIndex = 0

    // Deterministic placeholder estimate to match RideManager’s mock math
    private var estimate: RideEstimate {
        let base: Double = 5.0
        let pm = abs(pickup.hashValue % 7)
        let dm = abs(dropoff.hashValue % 9)
        let miles = base + Double(pm + dm) * 0.7
        let minutes = miles * 3.0
        return .init(distanceMiles: (miles * 10).rounded() / 10,
                     durationMinutes: round(minutes))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if rideManager.availableDrivers.isEmpty {
                    ProgressView("Finding nearby drivers…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    TabView(selection: $pageIndex) {
                        ForEach(Array(rideManager.availableDrivers.enumerated()), id: \.offset) { idx, d in
                            DriverTile(
                                driver: d,
                                estimate: estimate,
                                price: displayPrice(for: d),
                                rideType: rideType
                            ) {
                                rideManager.confirm(driver: d)
                            }
                            .padding(.horizontal)
                            .tag(idx)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .frame(height: 460) // room for the card + pager dots
                }
            }
            .overlay(awaitingOverlay)
            .navigationTitle("Nearby Drivers")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onClose)
                }
            }
            .onChange(of: rideManager.state) { _, newValue in
                if newValue == .inProgress { onAccepted() }
            }
        }
    }

    // MARK: - Pricing

    private struct Rules {
        let booking: Double
        let capPerMile: Double
        let capPerMinute: Double
    }

    private func rules(for type: String) -> Rules {
        switch type.lowercased() {
        case "rydr xl":
            return .init(booking: 5, capPerMile: 2.00, capPerMinute: 0.50)
        case "rydr prestine", "rydr pristine":
            return .init(booking: 8, capPerMile: 4.00, capPerMinute: 1.00)
        default: // Rydr Go
            return .init(booking: 4, capPerMile: 1.00, capPerMinute: 0.50)
        }
    }

    /// Price before promo.
    private func basePrice(for d: Driver) -> Double {
        let r = rules(for: rideType)
        let mileRate   = min(d.perMile,   r.capPerMile)
        let minuteRate = min(d.perMinute, r.capPerMinute)
        let total = r.booking
            + estimate.distanceMiles  * mileRate
            + estimate.durationMinutes * minuteRate
        return (total * 100).rounded() / 100.0
    }

    /// Final display price after promo (RideManager owns the applied promo).
    private func displayPrice(for d: Driver) -> Double {
        rideManager.applyPromo(to: basePrice(for: d))
    }

    // MARK: - Awaiting overlay

    @ViewBuilder
    private var awaitingOverlay: some View {
        if rideManager.state == .awaitingDriver {
            VStack(spacing: 10) {
                ProgressView("Contacting \(rideManager.selectedDriver?.name ?? "driver")…")
                Text("If they decline, you’ll come back to this screen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.thinMaterial)
        }
    }
}

// MARK: - Card tile

private struct DriverTile: View {
    let driver: Driver
    let estimate: RideEstimate
    let price: Double
    let rideType: String
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top row: avatar + name/rating + price
            HStack(alignment: .center) {
                // Avatar (image if available, fallback to initial)
                if let img = driver.profileImage, !img.isEmpty, UIImage(named: img) != nil {
                    Image(img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle().fill(.gray.opacity(0.15))
                        Text(String(driver.name.prefix(1))).font(.headline)
                    }
                    .frame(width: 52, height: 52)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(driver.name).font(.headline)
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill").font(.caption2)
                        Text(String(format: "%.1f", driver.rating))
                        Text("· \(driver.carMakeModel)")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(String(format: "%.2f", price))")
                        .font(.title3.bold())
                    Text(rideType)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Car image (or placeholder)
            Group {
                if let car = driver.carImage, !car.isEmpty, UIImage(named: car) != nil {
                    Image(car)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.gray.opacity(0.12))
                        .frame(height: 140)
                        .overlay(
                            VStack(spacing: 6) {
                                Image(systemName: "car.fill").font(.title2)
                                Text(driver.carMakeModel).font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        )
                }
            }

            // Distance / time
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                Text(String(format: "%.1f mi", estimate.distanceMiles))
                Text("•")
                Text("\(Int(estimate.durationMinutes)) min")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            // Compliment chips
            if !driver.compliments.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(driver.compliments.prefix(4), id: \.self) { c in
                        Text(c)
                            .font(.caption)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(.thinMaterial))
                    }
                }
                .accessibilityElement(children: .contain)
            }

            Button {
                onConfirm()
            } label: {
                Text("Confirm \(rideType) with \(driver.name)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThickMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .shadow(radius: 1, y: 1)
    }
}

// Small flow layout for compliment “chips”
private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                content
                    .alignmentGuide(.leading) { d in
                        if (abs(width - d.width) > geo.size.width) {
                            width = 0; height -= d.height + spacing
                        }
                        let result = width
                        if d.width != 0 { width -= d.width + spacing }
                        return result
                    }
                    .alignmentGuide(.top) { _ in height }
            }
        }
        .frame(height: 60) // ~2 lines of chips
    }
}



