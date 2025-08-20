//
//  RydrBankSummary.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 8/19/25.
//
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Models

struct RydrBankSummary: Codable {
    var eligibleCount: Int = 0           // progress since last reward
    var totalEligible: Int = 0           // lifetime eligible rides (5+ mi)
    var codesEarned: Int = 0             // lifetime codes minted
    var codesAvailable: Int = 0          // currently active codes
}

struct RydrBankCode: Identifiable {
    var id: String?
    var code: String
    var status: String                   // "active" | "reserved" | "used" | "void"
    var maxMiles: Int = 15
    var createdAt: Timestamp?
    var reservedRideId: String?
    var usedRideId: String?

    // transfer fields
    var originalOwnerUid: String
    var transferCount: Int = 0           // 0 or 1
    var transferable: Bool = true        // false after transfer
}

// MARK: - ViewModel

final class RydrBankVM: ObservableObject {
    @Published var summary = RydrBankSummary()
    @Published var codes: [RydrBankCode] = []
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var summaryListener: ListenerRegistration?
    private var codesListener: ListenerRegistration?

    func start() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        listenSummary(uid: uid)
        listenCodes(uid: uid)
    }
    func stop() {
        summaryListener?.remove()
        codesListener?.remove()
        summaryListener = nil
        codesListener = nil
    }

    private func listenSummary(uid: String) {
        summaryListener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                if let err = err { self.errorMessage = err.localizedDescription; return }
                guard let dict = snap?.data()?["rydrBank"] as? [String: Any] else { return }
                do {
                    let data = try JSONSerialization.data(withJSONObject: dict)
                    let decoded = try JSONDecoder().decode(RydrBankSummary.self, from: data)
                    DispatchQueue.main.async { self.summary = decoded }
                } catch {
                    self.errorMessage = "Decode error: \(error.localizedDescription)"
                }
            }
    }

    private func listenCodes(uid: String) {
        codesListener = db.collection("users").document(uid)
            .collection("rydrBankCodes")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                if let err = err { self.errorMessage = err.localizedDescription; return }
                self.codes = (snap?.documents ?? []).map { doc in
                    let d = doc.data()
                    return RydrBankCode(
                        id: doc.documentID,
                        code: d["code"] as? String ?? "",
                        status: d["status"] as? String ?? "active",
                        maxMiles: d["maxMiles"] as? Int ?? 15,
                        createdAt: d["createdAt"] as? Timestamp,
                        reservedRideId: d["reservedRideId"] as? String,
                        usedRideId: d["usedRideId"] as? String,
                        originalOwnerUid: d["originalOwnerUid"] as? String ?? "",
                        transferCount: d["transferCount"] as? Int ?? 0,
                        transferable: d["transferable"] as? Bool ?? true
                    )
                }
            }
    }

    // MARK: - Transfer (one time)
    private func makeError(_ message: String) -> Error {
        NSError(domain: "RydrBank", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    func transfer(code: RydrBankCode, to email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            completion(.failure(makeError("Please enter a valid email.")))
            return
        }
        guard code.status == "active", code.transferCount == 0, code.transferable else {
            completion(.failure(makeError("This code cannot be transferred.")))
            return
        }

        Task {
            guard let user = Auth.auth().currentUser else {
                completion(.failure(makeError("You must be logged in.")))
                return
            }
            do {
                let idToken = try await user.getIDToken()
                var req = URLRequest(url: URL(string: "https://rydr-bank.onrender.com/promo/transfer")!)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                let payload: [String: Any] = ["code": code.code, "recipientEmail": email]
                req.httpBody = try JSONSerialization.data(withJSONObject: payload)

                let (_, resp) = try await URLSession.shared.data(for: req)
                if let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                    completion(.success(()))
                } else {
                    completion(.failure(makeError("Transfer failed. Please try again.")))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
}

// MARK: - View

struct RydrBankView: View {
    @StateObject private var vm = RydrBankVM()

    // Transfer sheet state
    @State private var showTransferSheet = false
    @State private var transferTargetEmail = ""
    @State private var codePendingTransfer: RydrBankCode?

    // TEMP START: Dev mint helpers (remove when done testing)
    @State private var isMinting = false
    @State private var mintAlert: String?
    @State private var showMintAlert = false
    // TEMP END

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                balanceCard
                progressCard(eligibleModulo: vm.summary.eligibleCount % 10)
                codesSection

                // TEMP START: Dev button to mint 10 eligible rides and (likely) earn a code
                Button {
                    Task {
                        isMinting = true
                        do {
                            if let code = try await RydrBankAPI.mintTenDevRides() {
                                mintAlert = "Minted code: \(code)"
                            } else {
                                mintAlert = "No code minted. If some rides were already counted, run again."
                            }
                            showMintAlert = true
                        } catch {
                            mintAlert = "Mint failed: \(error.localizedDescription)"
                            showMintAlert = true
                        }
                        isMinting = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isMinting { ProgressView() }
                        Text(isMinting ? "Minting…" : "Dev: Mint 10 Eligible Rides")
                            .bold()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.horizontal)
                .alert("RydrBank", isPresented: $showMintAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(mintAlert ?? "")
                }
                // TEMP END

                Text("Earn 1 banked ride after every 10 completed rides of 5 miles or more. Each banked ride covers up to 15 miles on a single trip. Codes do not expire.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .padding(.top, 12)
            .navigationTitle("RydrBank")
        }
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
        .sheet(isPresented: $showTransferSheet) {
            NavigationView {
                Form {
                    Section(header: Text("Recipient")) {
                        TextField("Friend's email", text: $transferTargetEmail)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .keyboardType(.emailAddress)
                    }
                    Section {
                        Button("Send Transfer") { submitTransfer() }
                            .disabled(transferTargetEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Cancel", role: .cancel) { cancelTransferPrompt() }
                    }
                }
                .navigationTitle("Transfer Code")
            }
        }
    }

    // MARK: - Sections

    private var balanceCard: some View {
        VStack(spacing: 10) {
            Text("RydrBank Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(vm.summary.codesAvailable)")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(Styles.rydrGradient)
            Text("Banked free rides (up to 15 miles each)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
    }

    @ViewBuilder
    private func progressCard(eligibleModulo: Int) -> some View {
        let progress = max(0, min(eligibleModulo, 10))
        let remaining = max(0, 10 - progress)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress to next reward")
                    .font(.headline)
                    .foregroundStyle(Styles.rydrGradient)
                Spacer()
                Text("\(progress)/10")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Styles.rydrGradient)
                        .frame(width: geo.size.width * CGFloat(progress) / 10.0, height: 10)
                        .animation(.easeInOut(duration: 0.25), value: progress)
                }
            }
            .frame(height: 10)

            Text(remaining == 0
                 ? "Reward ready! Your next eligible ride will mint a free ride code."
                 : "\(remaining) more eligible \(remaining == 1 ? "ride" : "rides") (5+ miles) to earn a free ride.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
        )
        .padding(.horizontal)
    }

    private var codesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your Codes")
                    .font(.headline)
                    .foregroundStyle(Styles.rydrGradient)
                Spacer()
            }
            .padding(.horizontal)

            if vm.codes.isEmpty {
                Text("No codes yet. Complete rides to start banking free rides.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(vm.codes) { code in
                        codeRow(code)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func codeRow(_ code: RydrBankCode) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Styles.rydrGradient.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: icon(for: code.status))
                    .foregroundStyle(Styles.rydrGradient)
                    .font(.system(size: 20, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(code.code)
                    .font(.subheadline).bold()
                    .textSelection(.enabled)
                Text(label(for: code))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if code.status == "active", code.transferCount == 0, code.transferable {
                Button("Transfer") {
                    codePendingTransfer = code
                    transferTargetEmail = ""
                    showTransferSheet = true
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(code.code), \(label(for: code))")
    }

    private func icon(for status: String) -> String {
        switch status {
        case "active": return "checkmark.seal"
        case "reserved": return "hourglass"
        case "used": return "seal"
        case "void": return "xmark.seal"
        default: return "questionmark"
        }
    }

    private func label(for code: RydrBankCode) -> String {
        switch code.status {
        case "active":
            return code.transferCount == 0 && code.transferable
                ? "Ready to use • Transferable once"
                : "Ready to use"
        case "reserved": return "Reserved for an upcoming ride"
        case "used": return "Redeemed"
        case "void": return "Transferred"
        default: return "Unavailable"
        }
    }

    // MARK: - Transfer handlers

    private func submitTransfer() {
        guard let code = codePendingTransfer else { return }
        vm.transfer(code: code, to: transferTargetEmail) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    showTransferSheet = false
                    codePendingTransfer = nil
                    transferTargetEmail = ""
                case .failure(let error):
                    vm.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func cancelTransferPrompt() {
        showTransferSheet = false
        codePendingTransfer = nil
        transferTargetEmail = ""
    }
}


