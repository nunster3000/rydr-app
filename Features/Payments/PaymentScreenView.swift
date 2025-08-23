import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import StripePayments
import StripePaymentsUI

// MARK: - Main Screen

struct PaymentScreenView: View {
    var onComplete: () -> Void = {}
    var onSkip: () -> Void = {}
    var showSkip: Bool = true

    // Backend base
    private let backendBase = URL(string: "https://rydr-stripe-backend.onrender.com")!

    // State
    @State private var customerId: String?
    @State private var cards: [CardPM] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddCard = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Payment Methods")
                    .font(.largeTitle).bold()

                Text("Add or manage your saved cards.")
                    .foregroundStyle(.secondary)

                if cards.isEmpty {
                    EmptyWalletTile()
                        .frame(maxWidth: .infinity)
                        .onAppear { bootstrap() }
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(cards) { pm in
                            CardTile(
                                brand: pm.brand,
                                last4: pm.last4,
                                expMonth: pm.expMonth,
                                expYear: pm.expYear,
                                isDefault: pm.isDefault,
                                onMakeDefault: { makeDefault(pm.id) },
                                onDelete: { detach(pm.id) }
                            )
                        }
                    }
                }

                Button {
                    showAddCard = true
                } label: {
                    Text("Add Payment Method")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(customerId == nil || isLoading)

                if showSkip {
                    Button("Add Payment Later") { onSkip() }
                        .frame(maxWidth: .infinity)
                }

                if isLoading { ProgressView("Working…") }

                if let err = errorMessage {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { bootstrap() }
        .sheet(isPresented: $showAddCard, onDismiss: { if let cid = customerId { refreshPaymentMethods(for: cid) } }) {
            if let cid = customerId {
                AddCardSheet(backendBase: backendBase, customerId: cid) { result in
                    showAddCard = false
                    switch result {
                    case .success:
                        if let cid = customerId { refreshPaymentMethods(for: cid) }
                        onComplete()
                    case .failure(let err):
                        errorMessage = err.localizedDescription
                    }
                }
            }
        }
    }

    // MARK: - First-time setup

    private func bootstrap() {
        guard let user = Auth.auth().currentUser else {
            error("You must be logged in.")
            return
        }
        ensureCustomer(for: user) { result in
            switch result {
            case .success(let cid):
                self.customerId = cid
                self.refreshPaymentMethods(for: cid)
            case .failure(let e):
                self.error(e.localizedDescription)
            }
        }
    }

    private func ensureCustomer(for user: User, completion: @escaping (Result<String, Error>) -> Void) {
        let uid = user.uid
        let doc = Firestore.firestore().collection("riders").document(uid)

        doc.getDocument { snap, _ in
            if let cid = snap?.data()?["stripeCustomerId"] as? String, !cid.isEmpty {
                completion(.success(cid)); return
            }
            let email = user.email ?? "user-\(uid)@example.com"
            let name  = user.displayName ?? "Rydr User"

            requestJSON(path: "create-customer", body: ["email": email, "name": name, "uid": uid]) { (resp: CreateCustomerResponse?) in
                guard let cid = resp?.customerId, !cid.isEmpty else {
                    completion(.failure(NSError(domain: "Stripe", code: -1,
                                                userInfo: [NSLocalizedDescriptionKey: "No customerId from server"]))); return
                }
                doc.setData(["stripeCustomerId": cid], merge: true) { _ in
                    completion(.success(cid))
                }
            }
        }
    }

    // MARK: - List / Default / Detach

    private func refreshPaymentMethods(for customerId: String) {
        requestJSON(path: "list-payment-methods", body: ["customerId": customerId]) { (resp: ListPMsResponse?) in
            DispatchQueue.main.async {
                self.cards = resp?.paymentMethods ?? []
            }
        }
    }

    private func makeDefault(_ pmId: String) {
        guard let cid = customerId else { return }
        requestJSON(path: "set-default-payment-method", body: ["customerId": cid, "paymentMethodId": pmId]) { (_: SimpleOK?) in
            refreshPaymentMethods(for: cid)
        }
    }

    private func detach(_ pmId: String) {
        requestJSON(path: "detach-payment-method", body: ["paymentMethodId": pmId]) { (_: SimpleOK?) in
            if let cid = customerId { refreshPaymentMethods(for: cid) }
        }
    }

    // MARK: - Networking helper

    private func requestJSON<T: Decodable>(
        path: String,
        body: [String: Any],
        completion: @escaping (T?) -> Void
    ) {
        var req = URLRequest(url: backendBase.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        // Add Firebase ID token if present (useful if you lock down your backend later)
        func send(_ r: URLRequest) {
            URLSession.shared.dataTask(with: r) { data, _, _ in
                guard let data = data else { completion(nil); return }
                let obj = try? JSONDecoder().decode(T.self, from: data)
                completion(obj)
            }.resume()
        }

        if let user = Auth.auth().currentUser {
            user.getIDToken { token, _ in
                var r = req
                if let token { r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
                send(r)
            }
        } else {
            send(req)
        }
    }

    private func error(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.isLoading = false
        }
    }
}

// MARK: - Add Card Sheet (custom form + SetupIntent)

private struct AddCardSheet: View {
    let backendBase: URL
    let customerId: String
    let completion: (Result<Void, Error>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var canSubmit = false
    @State private var isWorking = false
    @State private var errorText: String?
    @State private var cardParams: STPPaymentMethodParams?

    // For 3DS flows from STPPaymentHandler
    @State private var presentingVC: UIViewController?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                CardFormRepresentable(paymentMethodParams: $cardParams, onEditingChanged: { canSubmit = $0 })
                    .frame(height: 220)

                if let e = errorText {
                    Text(e).foregroundStyle(.red).font(.footnote)
                }

                Button {
                    addCard()
                } label: {
                    if isWorking {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Save Card").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit || isWorking)

                Spacer()
            }
            .padding()
            .navigationTitle("Add Card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // Resolve a presenter ViewController for STPPaymentHandler
            .background(PresenterResolver { vc in presentingVC = vc })
        }
    }

    private func addCard() {
        guard let pmParams = cardParams else { return }
        errorText = nil; isWorking = true

        // 1) Create SetupIntent
        var req = URLRequest(url: backendBase.appendingPathComponent("create-setup-intent"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["customerId": customerId])

        URLSession.shared.dataTask(with: req) { data, _, err in
            if let err = err { finish(.failure(err)); return }
            guard let data = data,
                  let si = try? JSONDecoder().decode(SetupIntentResponse.self, from: data)
            else { finish(.failure(simple("Failed to create SetupIntent"))); return }

            // 2) Confirm SetupIntent with the card form params
            let confirm = STPSetupIntentConfirmParams(clientSecret: si.clientSecret)
            confirm.paymentMethodParams = pmParams

            let handler = STPPaymentHandler.shared()
            let ctx = AuthContext(presenting: presentingVC)

            handler.confirmSetupIntent(confirm, with: ctx) { status, _, error in
                switch status {
                case .succeeded:
                    finish(.success(()))
                case .failed:
                    finish(.failure(error ?? simple("Confirmation failed")))
                case .canceled:
                    finish(.failure(simple("Canceled")))
                @unknown default:
                    finish(.failure(simple("Unknown status")))
                }
            }
        }.resume()
    }

    private func finish(_ result: Result<Void, Error>) {
        DispatchQueue.main.async {
            isWorking = false
            if case .failure(let e) = result { errorText = e.localizedDescription }
            completion(result)
        }
    }

    private func simple(_ msg: String) -> NSError {
        NSError(domain: "AddCard", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
    }
}

// MARK: - Wallet-style card tiles

private struct CardTile: View {
    let brand: String
    let last4: String
    let expMonth: Int
    let expYear: Int
    let isDefault: Bool
    var onMakeDefault: () -> Void
    var onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: colors(for: brand), startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 6)
                .frame(height: 120)
                .overlay(
                    HStack {
                        Image(systemName: icon(for: brand))
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.leading, 16)
                        Spacer()
                    }
                )

            HStack(spacing: 8) {
                if isDefault {
                    Text("Default")
                        .font(.caption2).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                } else {
                    Button("Make Default", action: onMakeDefault)
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .padding(.trailing, 4)
                }
                Button(role: .destructive) { onDelete() } label: {
                    Image(systemName: "trash")
                }
                .font(.caption)
            }
            .padding(10)

            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                Text("•••• \(last4)")
                    .font(.title3).bold().monospacedDigit().foregroundStyle(.white)
                Text(String(format: "Exp %02d/%02d", expMonth, expYear % 100))
                    .font(.caption).foregroundStyle(.white.opacity(0.9))
            }
            .padding(16)
        }
    }

    private func colors(for brand: String) -> [Color] {
        switch brand.lowercased() {
        case "visa":        return [.blue, .indigo]
        case "mastercard":  return [.orange, .red]
        case "amex":        return [.teal, .blue]
        case "discover":    return [.orange, .brown]
        default:            return [.gray, .black.opacity(0.7)]
        }
    }
    private func icon(for brand: String) -> String {
        switch brand.lowercased() {
        case "visa":        return "v.circle.fill"
        case "mastercard":  return "m.circle.fill"
        case "amex":        return "a.circle.fill"
        case "discover":    return "d.circle.fill"
        default:            return "creditcard.fill"
        }
    }
}

private struct EmptyWalletTile: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [.gray.opacity(0.4), .black.opacity(0.6)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(height: 120)
            VStack(alignment: .leading, spacing: 6) {
                Text("No cards saved yet")
                    .font(.headline).foregroundStyle(.white)
                Text("Add a card to pay for rides quickly.")
                    .font(.caption).foregroundStyle(.white.opacity(0.9))
            }.padding(16)
        }
    }
}

// MARK: - Stripe Card Field wrapper (stable API)

private struct CardFormRepresentable: UIViewRepresentable {
    @Binding var paymentMethodParams: STPPaymentMethodParams?
    var onEditingChanged: (Bool) -> Void = { _ in }

    func makeUIView(context: Context) -> STPPaymentCardTextField {
        let view = STPPaymentCardTextField()
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: STPPaymentCardTextField, context: Context) {}

    func makeCoordinator() -> Coord { Coord(self) }

    final class Coord: NSObject, STPPaymentCardTextFieldDelegate {
        var parent: CardFormRepresentable
        init(_ parent: CardFormRepresentable) { self.parent = parent }

        func paymentCardTextFieldDidChange(_ textField: STPPaymentCardTextField) {
            // Modern API: use the field’s own STPPaymentMethodParams
            parent.paymentMethodParams = textField.paymentMethodParams
            parent.onEditingChanged(textField.isValid)
        }
    }
}


// MARK: - STPAuthenticationContext helpers

private final class AuthContext: NSObject, STPAuthenticationContext {
    private weak var presenting: UIViewController?
    init(presenting: UIViewController?) { self.presenting = presenting }
    func authenticationPresentingViewController() -> UIViewController {
        presenting ?? (UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController ?? UIViewController())
    }
}

private struct PresenterResolver: UIViewControllerRepresentable {
    var onResolve: (UIViewController) -> Void
    func makeUIViewController(context: Context) -> UIViewController {
        Resolver(onResolve: onResolve)
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    private final class Resolver: UIViewController {
        var onResolve: (UIViewController) -> Void
        init(onResolve: @escaping (UIViewController) -> Void) {
            self.onResolve = onResolve
            super.init(nibName: nil, bundle: nil)
        }
        required init?(coder: NSCoder) { fatalError() }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            onResolve(self)
        }
    }
}

// MARK: - DTOs

private struct CreateCustomerResponse: Decodable { let customerId: String }
private struct SetupIntentResponse: Decodable { let clientSecret: String }
private struct SimpleOK: Decodable { let ok: Bool }
private struct ListPMsResponse: Decodable { let paymentMethods: [CardPM] }

private struct CardPM: Decodable, Identifiable {
    let id: String
    let brand: String
    let last4: String
    let expMonth: Int
    let expYear: Int
    let isDefault: Bool
}






