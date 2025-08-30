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

    let rideType: String
    let pickup: String
    let dropoff: String
    let region: MKCoordinateRegion
    let onAccepted: () -> Void
    let onClose: () -> Void

    // UI state
    @State private var showConnecting = false
    @State private var showUnavailableBanner = false

    // Simple, deterministic estimate to match RideManager placeholder math
    private var estimate: RideEstimate {
        let base: Double = 5.0
        let pm = abs(pickup.hashValue % 7)
        let dm = abs(dropoff.hashValue % 9)
        let miles = base + Double(pm + dm) * 0.7
        let minutes = miles * 3.0
        return .init(distanceMiles: (miles * 10).rounded()/10, durationMinutes: round(minutes))
    }

    // DEV/QA helper: treat “any saved promo code” as 100% off in cards so users
    // can see a strikethrough and “FREE”. Your real discount logic still runs in RM.
    private var promoApplied: Bool {
        let a = UserDefaults.standard.string(forKey: "appliedPromoCode") ?? ""
        let b = UserDefaults.standard.string(forKey: "promoCode") ?? ""
        return !(a.isEmpty && b.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.point.left.fill").foregroundStyle(.secondary)
                        Text("Swipe to view nearby drivers")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Paged cards with dots
                    TabView {
                        ForEach(rideManager.availableDrivers) { d in
                            DriverCard(
                                rideManager: rideManager,
                                driver: d,
                                rideType: rideType,
                                estimate: estimate,
                                promoAppliedDevFree: promoApplied
                            ) {
                                confirm(d)   // ← show overlay, wait for accept/decline
                            }
                            .padding(.horizontal)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .indexViewStyle(.page(backgroundDisplayMode: .interactive))
                }

                // Decline banner
                if showUnavailableBanner {
                    UnavailableBanner(text: "Looks like the driver isn’t available. Let’s find you another driver!")
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
            }
            .navigationTitle("Nearby Drivers")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close", action: onClose)
                }
            }
        }
        // React to RideManager state to drive overlay + transitions
        .onChange(of: rideManager.state, initial: false) { _, newState in
            switch newState {
            case .awaitingDriver:
                withAnimation { showConnecting = true }
            case .inProgress:
                withAnimation { showConnecting = false }
                onAccepted() // navigate/present RideInProgressView from parent
            case .selecting:
                // If we were connecting and bounced back, show banner
                if showConnecting {
                    withAnimation { showUnavailableBanner = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation { showUnavailableBanner = false }
                    }
                }
                showConnecting = false
            default:
                break
            }
        }
        // Full-screen connecting animation while we wait
        .fullScreenCover(isPresented: $showConnecting) {
            ConnectingOverlay(
                title: "Connecting with \(rideManager.selectedDriver?.name ?? "driver")…",
                subtitle: "Confirming your ride request",
                gradient: Styles.rydrGradient
            )
            .ignoresSafeArea()
        }
    }

    private func confirm(_ driver: Driver) {
        rideManager.confirm(driver: driver)
        // state change to .awaitingDriver will trigger overlay via onChange
    }
}

private struct DriverCard: View {
    @ObservedObject var rideManager: RideManager
    let driver: Driver
    let rideType: String
    let estimate: RideEstimate
    let promoAppliedDevFree: Bool
    let onConfirm: () -> Void

    private var baseFare: Double {
        // Same as RideManager.fareFor() math
        let variable = estimate.distanceMiles * driver.perMile + estimate.durationMinutes * driver.perMinute
        let base: Double = 2.50
        return (base + variable).rounded(to: 2)
    }

    private var finalFare: Double {
        // Show FREE when any promo is present during testing;
        // otherwise honor RideManager’s applyPromo for %/cap logic.
        if promoAppliedDevFree { return 0 }
        return rideManager.applyPromo(to: baseFare)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                // avatar
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .overlay(Text(String(driver.name.prefix(1))).font(.headline))
                    .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 2) {
                    Text(driver.name).font(.headline)
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill").foregroundStyle(.yellow)
                        Text(String(format: "%.1f", driver.rating))
                        Text("· \(driver.carMakeModel)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if finalFare < baseFare - 0.009 {
                        // Strikethrough original, show discounted (or FREE)
                        Text("$\(baseFare, specifier: "%.2f")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .strikethrough()
                        Text(finalFare == 0 ? "FREE" : "$\(finalFare, specifier: "%.2f")")
                            .font(.headline).bold()
                    } else {
                        Text("$\(baseFare, specifier: "%.2f")")
                            .font(.headline).bold()
                    }
                    Text(rideTypeDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Car block – fixed height to avoid distortion
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                VStack(spacing: 10) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(driver.carMakeModel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 180)

            // Distance + ETA (from estimate to keep stable)
            HStack(spacing: 14) {
                Image(systemName: "figure.walk.motion")
                Text("\(estimate.distanceMiles, specifier: "%.1f") mi")
                Text("·")
                Text("\(Int(estimate.durationMinutes)) min")
                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            // Compliments (chips)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(driver.compliments, id: \.self) { c in
                        Text(c)
                            .font(.footnote)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.12)))
                    }
                }
            }

            Button {
                onConfirm()
            } label: {
                Text("Confirm \(rideTypeDisplay) with \(driver.name)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(RydrGradientButton())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var rideTypeDisplay: String {
        switch rideType.lowercased() {
        case "go":        return "Rydr Go"
        case "xl":        return "Rydr XL"
        case "prestine":  return "Rydr Prestine"
        default:          return rideType
        }
    }
}

// MARK: - Helpers

private struct RydrGradientButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 14)
            .background(Styles.rydrGradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct ConnectingOverlay: View {
    let title: String
    let subtitle: String
    let gradient: LinearGradient

    @State private var spin = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 22) {
                // Pulsing, spinning gradient ring
                ZStack {
                    Circle()
                        .stroke(gradient, lineWidth: 10)
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(spin ? 360 : 0))
                        .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: spin)

                    Circle()
                        .fill(gradient)
                        .frame(width: 24, height: 24)
                        .scaleEffect(pulse ? 1.0 : 0.6)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                }
                .onAppear { spin = true; pulse = true }

                VStack(spacing: 6) {
                    Text(title).font(.title3).bold()
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("This usually takes only a moment…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }
}

private struct UnavailableBanner: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Styles.rydrGradient)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

private extension Double {
    func rounded(to places: Int) -> Double {
        let p = pow(10.0, Double(places))
        return (self * p).rounded() / p
    }
}






