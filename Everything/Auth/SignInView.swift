//
//  SignInView.swift
//  Everything
//
//  Created by Karen Karapetyan on 16.04.26.
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            BackgroundView()

            VStack(spacing: 0) {
                Spacer()

                // App identity
                VStack(spacing: 14) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 64, weight: .thin))
                        .foregroundStyle(.primary.opacity(0.75))
                        .padding(.bottom, 8)

                    Text("Everything")
                        .font(.system(size: 42, weight: .bold, design: .rounded))

                    Text("A fluid workspace for chats,\nAI tools, apps, and preferences.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()
                Spacer()

                // Sign in controls
                VStack(spacing: 14) {
                    if authService.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        VStack(spacing: 12) {
                            SignInWithAppleButton(.continue) { request in
                                request.requestedScopes = [.fullName, .email]
                                request.nonce = authService.prepareAppleSignIn()
                            } onCompletion: { result in
                                Task { await authService.handleAppleSignIn(result) }
                            }
                            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            Button {
                                authService.signInWithGoogle()
                            } label: {
                                HStack(spacing: 8) {
                                    Spacer()

                                    ZStack {
                                        Circle()
                                            .fill(Color.white)

                                        Text("G")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundStyle(.blue)
                                    }
                                    .frame(width: 22, height: 22)

                                    Text(String(localized: "Continue with Google", comment: "Button title for signing in with Google"))
                                        .font(.system(size: 17, weight: .medium))
                                        .lineLimit(1)

                                    Spacer()
                                }
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                                .padding(.horizontal, 14)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color(uiColor: .systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.08), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    
                    

                    if let message = authService.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Text("By signing in you agree to our Terms & Privacy Policy.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthService())
}
