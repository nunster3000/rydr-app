import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import StripePayments
import StripePaymentsUI

/// Wallet-style management of a customer's saved cards (Profile screen)
struct PaymentMethodView: View {
    // If you present this view standalone and want it to draw its own title, set true.
    var showsHeader: Bool = false

    private let backendBase = URL(string: "https://rydr-stripe-backend.onrender.com")!

    @State private var customerId: String?
    @State private var cards: [CardPM] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Add/Edit sheet
    @State private var showAddCard = false
    @State private var editingPMId: String? = nil       // when not nil we’re “editing” (replace flow)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if showsHeader {
                    Text("Payment Methods")
                        .font(.largeTitle).bold()
                }

                Text("Add a card to use for future rides. You can remove it anytime.")
                    .foregroundStyle(.secondary)

                if isLoading {
                    ProgressView("Working…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let err = errorMessage {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .multilineTextAlignment(.leading)
                }

                if cards.isEmpty {
                    EmptyWalletTile()
                        .frame(maxWidth: .infinity)
                        .onAppear { bootstrapIfNeeded() }
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
                                onEdit: {
                                    editingPMId = pm.id
                                    showAddCard = true
                                },
                                onDelete: { detach(pm.id) }
                            )
                        }
                    }
                }

                Button {
                    editingPMId = nil
                    showAddCard = true
                } label: {
                    Text("Add Payment Method")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(customerId == nil || isLoading)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { bootstrapIfNeeded() }
        .sheet(isPresented: $showAddCard, onDismiss: { reloadIfPossible() }) {
            if let cid = customerId {
                AddOrReplaceCardSheet(
                    backendBase: backendBase,
                    customerId: cid,
                    replacePaymentMethodId: editingPMId
                ) { result in
                    showAddCard = false
                    switch result {
                    case .success(let newPMId):
                        // If this was an “edit”, make the new one default and remove the old
                        if let oldId = editingPMId {
                            setDefault(newPMId) { _ in
                                detach(oldId) { _ in reloadIfPossible() }
                            }
                        } else {
                            // Added new card from the button; refresh list
                            reloadIfPossible()
                        }
                    case .failure(let e):
                        errorMessage = e.localizedDescription
                    }
                }
            }
        }
    }
}

// MARK: - First-time setup & data loading
private extension PaymentMethodView {
    func bootstrapIfNeeded() {
        guard customerId == nil else { return }
        guard let user = Auth.auth().currentUser else {
            errorMessage = "You must be logged in."
            return
        }
        isLoading = true
        ensureCustomer(for: user) { result in
            switch result {
            case .success(let cid):
                self.customerId = cid
                self.refreshPaymentMethods(for: cid)
            case .failure(let e):
                self.errorMessage = e.localizedDescription
                self.isLoading = false
            }
        }
    }

    func reloadIfPossible() {
        if let cid = customerId { refreshPaymentMethods(for: cid) }
    }

    func ensureCustomer(for user: User, completion: @escaping (Result<String, Error>) -> Void) {
        let uid = user.uid
        let doc = Firestore.firestore().collection("riders").document(uid)

        doc.getDocument { snap, _ in
            if let cid = snap?.data()?["stripeCustomerId"] as? String, !cid.isEmpty {
                completion(.success(cid)); return
            }
            let email = user.email ?? "user-\(uid)@example.com"
            let name  = user.displayName ?? "Rydr User"

            requestJSON(
                backendBase: backendBase,
                path: "create-customer",
                body: ["email": email, "name": name, "uid": uid],
                decode: CreateCustomerResponse.self
            ) { resp in
                guard let cid = resp?.customerId, !cid.isEmpty else {
                    completion(.failure(simple("Failed to create customer"))); return
                }
                doc.setData(["stripeCustomerId": cid], merge: true) { _ in
                    completion(.success(cid))
                }
            }
        }
    }

    func refreshPaymentMethods(for customerId: String) {
        isLoading = true
        requestJSON(
            backendBase: backendBase,
            path: "list-payment-methods",
            body: ["customerId": customerId],
            decode: ListPMsResponse.self
        ) { resp in
            DispatchQueue.main.async {
                self.cards = resp?.paymentMethods ?? []
                self.isLoading = false
            }
        }
    }
}

// MARK: - Actions
private extension PaymentMethodView {
    func makeDefault(_ pmId: String) {
        guard let cid = customerId else { return }
        setDefault(pmId) { _ in refreshPaymentMethods(for: cid) }
    }

    func setDefault(_ pmId: String, completion: @escaping (Bool) -> Void) {
        requestJSON(
            backendBase: backendBase,
            path: "set-default-payment-method",
            body: ["customerId": customerId ?? "", "paymentMethodId": pmId],
            decode: SimpleOK.self
        ) { _ in completion(true) }
    }

    func detach(_ pmId: String, completion: ((Bool) -> Void)? = nil) {
        requestJSON(
            backendBase: backendBase,
            path: "detach-payment-method",
            body: ["paymentMethodId": pmId],
            decode: SimpleOK.self
        ) { _ in
            completion?(true)
            reloadIfPossible()
        }
    }
}

// MARK: - Networking helper
private func requestJSON<T: Decodable>(
    backendBase: URL,
    path: String,
    body: [String: Any],
    decode: T.Type,
    completion: @escaping (T?) -> Void
) {
    var req = URLRequest(url: backendBase.appendingPathComponent(path))
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

    func send(_ r: URLRequest) {
        URLSession.shared.dataTask(with: r) { data, _, _ in
            guard let data else { completion(nil); return }
            completion(try? JSONDecoder().decode(T.self, from: data))
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

private func simple(_ msg: String) -> NSError {
    NSError(domain: "PaymentMethods", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
}

// MARK: - Wallet-style card tile
private struct CardTile: View {
    let brand: String
    let last4: String
    let expMonth: Int
    let expYear: Int
    let isDefault: Bool
    var onMakeDefault: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: colors(for: brand), startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .frame(height: 130)
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
                        .tint(.white)
                        .foregroundStyle(.white)
                }
                Button { onEdit() } label: {
                    Image(systemName: "pencil")
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(.white)

                Button(role: .destructive) { onDelete() } label: {
                    Image(systemName: "trash")
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(.red)
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
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .frame(height: 130)
            VStack(alignment: .leading, spacing: 6) {
                Text("No cards saved yet")
                    .font(.headline).foregroundStyle(.white)
                Text("Add a card to pay for rides quickly.")
                    .font(.caption).foregroundStyle(.white.opacity(0.9))
            }.padding(16)
        }
    }
}

// MARK: - Add / Replace card sheet
/// If `replacePaymentMethodId` is provided, this sheet behaves like “Edit”:
/// it confirms a new card, makes it default, then the caller can detach the old one.
private struct AddOrReplaceCardSheet: View {
    let backendBase: URL
    let customerId: String
    let replacePaymentMethodId: String?
    let completion: (Result<String, Error>) -> Void   // returns new PM id

    @Environment(\.dismiss) private var dismiss
    @State private var canSubmit = false
    @State private var isWorking = false
    @State private var errorText: String?
    @State private var cardParams: STPPaymentMethodParams?
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
                        Text(replacePaymentMethodId == nil ? "Save Card" : "Replace Card")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit || isWorking)

                Spacer()
            }
            .padding()
            .navigationTitle(replacePaymentMethodId == nil ? "Add Card" : "Edit Card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .background(PresenterResolver { vc in presentingVC = vc })
        }
    }

    private func addCard() {
        guard let pmParams = cardParams else { return }
        errorText = nil; isWorking = true

        var req = URLRequest(url: backendBase.appendingPathComponent("create-setup-intent"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["customerId": customerId])

        URLSession.shared.dataTask(with: req) { data, _, err in
            if let err = err { finish(.failure(err)); return }
            guard let data = data,
                  let si = try? JSONDecoder().decode(SetupIntentResponse_Profile.self, from: data)
            else { finish(.failure(simple("Failed to create SetupIntent"))); return }

            let confirm = STPSetupIntentConfirmParams(clientSecret: si.clientSecret)
            confirm.paymentMethodParams = pmParams

            let handler = STPPaymentHandler.shared()
            let ctx = AuthContext(presenting: presentingVC)

            handler.confirmSetupIntent(confirm, with: ctx) { status, setupIntent, error in
                switch status {
                case .succeeded:
                    // The new payment method should now be attached to the customer
                    let newPMId = setupIntent?.paymentMethodID ?? ""
                    if newPMId.isEmpty {
                        finish(.failure(simple("Card saved but could not resolve payment method id.")))
                    } else {
                        finish(.success(newPMId))
                    }
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

    private func finish(_ result: Result<String, Error>) {
        DispatchQueue.main.async {
            isWorking = false
            if case .failure(let e) = result { errorText = e.localizedDescription }
            completion(result)
        }
    }
}

// MARK: - Card form wrapper
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
            parent.paymentMethodParams = textField.paymentMethodParams
            parent.onEditingChanged(textField.isValid)
        }
    }
}

// MARK: - Auth context helpers
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
    func makeUIViewController(context: Context) -> UIViewController { Resolver(onResolve: onResolve) }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    private final class Resolver: UIViewController {
        var onResolve: (UIViewController) -> Void
        init(onResolve: @escaping (UIViewController) -> Void) { self.onResolve = onResolve; super.init(nibName: nil, bundle: nil) }
        required init?(coder: NSCoder) { fatalError() }
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); onResolve(self) }
    }
}

// MARK: - DTOs
private struct CreateCustomerResponse: Decodable { let customerId: String }
private struct SetupIntentResponse_Profile: Decodable { let clientSecret: String }
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



