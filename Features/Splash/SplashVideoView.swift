//
//  SplashVideoView.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/14/25.
//
import SwiftUI
import AVKit

struct SplashVideoView: View {
    let onFinished: () -> Void
    @State private var fadeOut = false

    var body: some View {
        ZStack {
            VideoPlayerView(videoName: "AnimatedLogo", onFinish: {
                // Start fade out when the video finishes
                withAnimation(.easeOut(duration: 1.0)) {
                    fadeOut = true
                }

                // After fade out is done, move to next view
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onFinished()
                }
            })
            .opacity(fadeOut ? 0 : 1)
            .transition(.opacity)
            .ignoresSafeArea()
        }
    }
}


