//
//  TelegramTheme.swift
//  Everything
//

import SwiftUI
import UIKit

enum TelegramTheme {
    static let accent = Color(red: 0.17, green: 0.58, blue: 0.96)
    static let accentBright = Color(red: 0.29, green: 0.71, blue: 0.99)
    static let accentText = Color(red: 0.10, green: 0.52, blue: 0.92)
    static let listBackground = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let separator = Color(uiColor: .separator)
    static let searchFill = Color(uiColor: .tertiarySystemFill)
    static let incomingBubble = Color.white.opacity(0.84)
    static let incomingBubbleDark = Color.white.opacity(0.12)
    static let success = Color(red: 0.20, green: 0.78, blue: 0.36)
    static let draft = Color(red: 0.90, green: 0.32, blue: 0.30)
}

struct TelegramListBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .light {
                TelegramTheme.listBackground

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.80),
                        TelegramTheme.accent.opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Color(red: 0.08, green: 0.10, blue: 0.14)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.05),
                        TelegramTheme.accent.opacity(0.12),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
}

struct TelegramThreadBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .light {
                lightWallpaper
            } else {
                darkWallpaper
            }
        }
        .ignoresSafeArea()
    }

    private var lightWallpaper: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.69, green: 0.81, blue: 0.95),
                    Color(red: 0.81, green: 0.89, blue: 0.97),
                    Color(red: 0.93, green: 0.95, blue: 0.97)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Color.white.opacity(0.26))
                .frame(width: 280, height: 280)
                .blur(radius: 18)
                .offset(x: 140, y: -230)

            Circle()
                .fill(TelegramTheme.accent.opacity(0.12))
                .frame(width: 220, height: 220)
                .blur(radius: 12)
                .offset(x: -150, y: -280)

            Ellipse()
                .fill(Color(red: 0.98, green: 0.63, blue: 0.35))
                .frame(width: 620, height: 320)
                .rotationEffect(.degrees(-10))
                .offset(x: 80, y: 330)

            Ellipse()
                .fill(Color.white.opacity(0.22))
                .frame(width: 360, height: 120)
                .rotationEffect(.degrees(18))
                .offset(x: 160, y: 190)
        }
    }

    private var darkWallpaper: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.12, blue: 0.20),
                    Color(red: 0.06, green: 0.10, blue: 0.18),
                    Color(red: 0.04, green: 0.06, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(TelegramTheme.accent.opacity(0.24))
                .frame(width: 280, height: 280)
                .blur(radius: 24)
                .offset(x: 110, y: -250)

            Ellipse()
                .fill(Color(red: 0.71, green: 0.38, blue: 0.18).opacity(0.88))
                .frame(width: 640, height: 320)
                .rotationEffect(.degrees(-12))
                .offset(x: 100, y: 340)

            Ellipse()
                .fill(Color.white.opacity(0.05))
                .frame(width: 360, height: 120)
                .rotationEffect(.degrees(18))
                .offset(x: 160, y: 180)
        }
    }
}

struct TelegramGlassCircle: View {
    let icon: String
    var iconColor: Color = .primary
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(iconColor)
            .frame(width: size, height: size)
            .background(.ultraThinMaterial, in: Circle())
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.38), lineWidth: 1)
            }
    }
}
