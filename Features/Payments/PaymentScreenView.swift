import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import StripePayments
import StripePaymentsUI

/// Signup-only screen: lets the user add a card now, or (optionally) **Add Payment Later**.
/// It does NOT list existing cards.
struct PaymentScreenView: View {
    var onComplete: () -> Void = {}
    var onSkip: () -> Void = {}
    var showSkip: Bool = false   // ⬅️ default OFF; pass true only during signup

    // Backend base
    private let backendBase = URL(string: "https://rydr-stripe-backend.onrender.com")!

    // State
    @State private var customerId: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddCard = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Payment Methods").font(.largeTitle).bold()

            Text("Add a card to use for future rides.")
                .foregroundStyle(.secondary)

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

            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { bootstrap() }
        .sheet(isPresented: $showAddCard) {
            if let cid = customerId {
                AddCardSheet_Signup(backendBase: backendBase, customerId: cid) { result in
                    showAddCard = false
                    switch result {
                    case .success: onComplete()
                    case .failure(let err): errorMessage = err.localizedDescription
                    }
                }
            }
        }
    }

    // MARK: - Setup

    private func bootstrap() {
        guard let user = Auth.auth().currentUser else {
            error("You must be logged in.")
            return
        }
        ensureCustomer(for: user) { result in
            if case .success(let cid) = result {
                self.customerId = cid
            } else if case .failure(let e) = result {
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

            requestJSON(path: "create-customer", body: ["email": email, "name": name, "uid": uid]) { (resp: CreateCustomerResponse_Signup?) in
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

    private func requestJSON<T: Decodable>(
        path: String,
        body: [String: Any],
        completion: @escaping (T?) -> Void
    ) {
        var req = URLRequest(url: backendBase.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

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

// MARK: - Minimal Add-card sheet for signup (distinct type names to avoid clashes)

private struct AddCardSheet_Signup: View {
    let backendBase: URL
    let customerId: String
    let completion: (Result<Void, Error>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var canSubmit = false
    @State private var isWorking = false
    @State private var errorText: String?
    @State private var cardParams: STPPaymentMethodParams?
    @State private var presentingVC: UIViewController?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                CardFormRepresentable_Signup(paymentMethodParams: $cardParams, onEditingChanged: { canSubmit = $0 })
                    .frame(height: 220)

                if let e = errorText {
                    Text(e).foregroundStyle(.red).font(.footnote)
                }

                Button {
                    addCard()
                } label: {
                    if isWorking { ProgressView().frame(maxWidth: .infinity) }
                    else { Text("Save Card").frame(maxWidth: .infinity) }
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
            .background(PresenterResolver_Signup { vc in presentingVC = vc })
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
                  let si = try? JSONDecoder().decode(SetupIntentResponse_Signup.self, from: data)
            else { finish(.failure(simple("Failed to create SetupIntent"))); return }

            let confirm = STPSetupIntentConfirmParams(clientSecret: si.clientSecret)
            confirm.paymentMethodParams = pmParams

            let handler = STPPaymentHandler.shared()
            let ctx = AuthContext_Signup(presenting: presentingVC)

            handler.confirmSetupIntent(confirm, with: ctx) { status, _, error in
                switch status {
                case .succeeded: finish(.success(()))
                case .failed:    finish(.failure(error ?? simple("Confirmation failed")))
                case .canceled:  finish(.failure(simple("Canceled")))
                @unknown default:finish(.failure(simple("Unknown status")))
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

// MARK: - Small helpers (separate names to avoid duplicate-type compile errors)

private struct CardFormRepresentable_Signup: UIViewRepresentable {
    @Binding var paymentMethodParams: STPPaymentMethodParams?
    var onEditingChanged: (Bool) -> Void = { _ in }
    func makeUIView(context: Context) -> STPPaymentCardTextField {
        let v = STPPaymentCardTextField(); v.delegate = context.coordinator; return v
    }
    func updateUIView(_ uiView: STPPaymentCardTextField, context: Context) {}
    func makeCoordinator() -> Coord { Coord(self) }
    final class Coord: NSObject, STPPaymentCardTextFieldDelegate {
        var parent: CardFormRepresentable_Signup
        init(_ p: CardFormRepresentable_Signup) { parent = p }
        func paymentCardTextFieldDidChange(_ t: STPPaymentCardTextField) {
            parent.paymentMethodParams = t.paymentMethodParams
            parent.onEditingChanged(t.isValid)
        }
    }
}

private final class AuthContext_Signup: NSObject, STPAuthenticationContext {
    private weak var presenting: UIViewController?
    init(presenting: UIViewController?) { self.presenting = presenting }
    func authenticationPresentingViewController() -> UIViewController {
        presenting ?? (UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController ?? UIViewController())
    }
}
private struct PresenterResolver_Signup: UIViewControllerRepresentable {
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

// DTOs with unique names in this file
private struct CreateCustomerResponse_Signup: Decodable { let customerId: String }
private struct SetupIntentResponse_Signup: Decodable { let clientSecret: String }







