//
//  EndRideView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 8/29/25.
//
import SwiftUI

struct EndRideView: View {
    let ride: Receipt?
    let onDone: () -> Void

    @State private var rating: Int = 0
    @State private var selectedCompliments: Set<String> = []
    @State private var selectedTip: Int = 0     // cents
    @State private var extraNotes: String = ""

    private let complimentSet = [
        "Clean Car","Friendly","Great Service","Excellent Navigation",
        "Smooth Driving","Great Conversation"
    ]
    private let tipOptions: [Int] = [0, 200, 500, 1000]   // $0, $2, $5, $10

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    starsSection
                    complimentsSection
                    tipSection
                    notesSection
                    submitSection
                }
                .padding()
            }
            .navigationTitle("Rate your ride")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { onDone() }
                }
            }
        }
    }

    // MARK: - Sections (small views = fast type-check)

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Trip complete")
                .font(.headline)
            if let r = ride {
                Text("\(r.pickup) → \(r.dropoff)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var starsSection: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { i in
                Button {
                    rating = i
                } label: {
                    Image(systemName: i <= rating ? "star.fill" : "star")
                        .font(.title)
                        .foregroundStyle(.red)   // keep simple & readable
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue("\(rating) stars")
    }

    private var complimentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Compliments").font(.headline)

            // lightweight pill grid
            let cols = [GridItem(.adaptive(minimum: 140), spacing: 10)]
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(complimentSet, id: \.self) { c in
                    let isOn = selectedCompliments.contains(c)
                    Button {
                        if isOn { selectedCompliments.remove(c) }
                        else    { selectedCompliments.insert(c) }
                    } label: {
                        Text(c)
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .background(RoundedRectangle(cornerRadius: 10).fill(isOn ? Color.red.opacity(0.12) : Color(.systemGray6)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isOn ? Color.red : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var tipSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tip").font(.headline)
            HStack(spacing: 10) {
                ForEach(tipOptions, id: \.self) { cents in
                    let isOn = selectedTip == cents
                    Button {
                        selectedTip = cents
                    } label: {
                        Text(cents == 0 ? "No tip" : "$\(cents/100)")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(isOn ? Color.red.opacity(0.12) : Color(.systemGray6)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isOn ? Color.red : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Anything to add?").font(.headline)
            TextEditor(text: $extraNotes)
                .frame(minHeight: 90)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        }
    }

    private var submitSection: some View {
        Button {
            // You can capture rating/compliments/tip/notes here if you want
            onDone()
        } label: {
            Text("Submit").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 4)
    }
}



