//
//  GradientColor.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/14/25.
//
import SwiftUI

struct Styles {
    static let rydrGradient = LinearGradient(
        colors: [Color.red, Color(red: 0.5, green: 0.0, blue: 0.13).opacity(0.7)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

