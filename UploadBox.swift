//
//  UploadBox.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/14/25.
//
import SwiftUI

struct UploadBox: View {
    var label: String

    var body: some View {
        Text(label)
            .font(.caption)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, minHeight: 50)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [Color.red, Color(red: 0.5, green: 0.0, blue: 0.13).opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .background(Color.white)
            .cornerRadius(8)
            .shadow(radius: 2)
    }
}

