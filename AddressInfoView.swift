//
//  AddressEntryView.swift
//  RydrSignupFlow
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AddressInfoView: View {
    @Binding var street: String
    @Binding var addressLine2: String
    @Binding var city: String
    @Binding var state: String
    @Binding var zipCode: String
    var onNext: () -> Void
    
    @State private var goToPayment = false
    
    private let usStates = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
        "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
        "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
        "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
        "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"
    ]
    
    var body: some View {
        VStack(spacing: 25) {
            Text("Where Are You Located?")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.red, Color(red: 0.5, green: 0.0, blue: 0.13).opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Group {
                HStack {
                    Image(systemName: "house")
                        .foregroundColor(.gray)
                    TextField("Street Address", text: $street)
                }
                .inputFieldStyle()
                
                HStack {
                    Image(systemName: "number")
                        .foregroundColor(.gray)
                    TextField("Apt, Suite, etc. (optional)", text: $addressLine2)
                }
                .inputFieldStyle()
                
                HStack {
                    Image(systemName: "building.2")
                        .foregroundColor(.gray)
                    TextField("City", text: $city)
                }
                .inputFieldStyle()
                
                HStack {
                    Image(systemName: "map")
                        .foregroundColor(.gray)
                    Picker("State", selection: $state) {
                        ForEach(usStates, id: \.self) { abbreviation in
                            Text(abbreviation).tag(abbreviation)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .inputFieldStyle()
                
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.gray)
                    TextField("ZIP Code", text: $zipCode)
                        .keyboardType(.numberPad)
                }
                .inputFieldStyle()
            }
            
            Button("Continue") {
                goToPayment = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            
            .navigationDestination(isPresented: $goToPayment) {
                PaymentScreenViewWrapper(
                    clientSecret: "your_test_or_dynamic_client_secret",
                    onComplete: {
                        goToPayment = false
                        onNext()
                    }
                )
                
                VStack(spacing: 25) {
                    // ... all your form fields
                    
                    Button("Continue") {
                        goToPayment = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding()
                .navigationDestination(isPresented: $goToPayment) {
                    PaymentScreenViewWrapper(
                        clientSecret: "your_test_or_dynamic_client_secret",
                        onComplete: {
                            goToPayment = false
                            onNext()
                        }
                    )
                }
                
            }
        }
    }
    struct PaymentScreenViewWrapper: View {
        var clientSecret: String
        var onComplete: () -> Void
        @State private var showingPaymentSheet = true
        
        var body: some View {
            EmptyView()
                .sheet(isPresented: $showingPaymentSheet, onDismiss: onComplete) {
                    PaymentMethodView(clientSecret: clientSecret) { result in
                        switch result {
                        case .success(let paymentMethodId):
                            print("✅ Payment Method Created: \(paymentMethodId)")
                            savePaymentMethodToFirestore(paymentMethodId)
                        case .failure(let error):
                            print("❌ Payment failed: \(error.localizedDescription)")
                        }
                        showingPaymentSheet = false
                    }
                }
        }
        
        private func savePaymentMethodToFirestore(_ paymentMethodId: String) {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            let db = Firestore.firestore()
            db.collection("users").document(userId).setData([
                "paymentMethodId": paymentMethodId
            ], merge: true)
        }
    }
}
