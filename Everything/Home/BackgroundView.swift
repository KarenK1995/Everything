//
//  BackgroundView.swift
//  Everything
//
//  Created by Karen Karapetyan on 16.04.26.
//

import SwiftUI

struct BackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .light {
                lightBackground
            } else {
                darkBackground
            }
        }
        .ignoresSafeArea()
    }

    private var lightBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.99, blue: 0.98),
                    Color.white,
                    Color(red: 0.985, green: 0.985, blue: 0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color(red: 0.79, green: 0.90, blue: 0.98).opacity(0.22),
                    Color(red: 0.88, green: 0.95, blue: 1.0).opacity(0.09),
                    .clear
                ],
                center: .leading,
                startRadius: 18,
                endRadius: 220
            )
            .offset(x: -35, y: -40)

            RadialGradient(
                colors: [
                    Color(red: 0.98, green: 0.89, blue: 0.83).opacity(0.20),
                    Color(red: 1.0, green: 0.94, blue: 0.90).opacity(0.08),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 210
            )
            .offset(x: 20, y: -30)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.0),
                    Color(red: 0.97, green: 0.97, blue: 0.96).opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var darkBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.11, blue: 0.12),
                    Color(red: 0.08, green: 0.08, blue: 0.09),
                    Color(red: 0.04, green: 0.04, blue: 0.05),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color(red: 0.39, green: 0.52, blue: 0.66).opacity(0.18),
                    Color(red: 0.20, green: 0.28, blue: 0.36).opacity(0.08),
                    .clear
                ],
                center: .leading,
                startRadius: 18,
                endRadius: 240
            )
            .offset(x: -30, y: -60)

            RadialGradient(
                colors: [
                    Color(red: 0.47, green: 0.42, blue: 0.39).opacity(0.16),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 220
            )
            .offset(x: 30, y: -30)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.04),
                    .clear,
                    Color.black.opacity(0.24)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

#Preview {
    BackgroundView()
}
