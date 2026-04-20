//
//  ProfileView.swift
//  Everything
//
//  Created by Karen Karapetyan on 16.04.26.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false

    private var user: FirebaseAuth.User? { authService.currentUser }

    private var displayName: String {
        user?.displayName?.isEmpty == false ? user!.displayName! : "User"
    }

    private var email: String {
        user?.email ?? user?.providerData.first?.email ?? ""
    }

    private var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return (String(parts[0].prefix(1)) + String(parts[1].prefix(1))).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {

                        // Header
                        HStack(spacing: 16) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.94, green: 0.53, blue: 0.42),
                                            Color(red: 0.87, green: 0.33, blue: 0.28)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 72, height: 72)
                                .overlay {
                                    Text(initials)
                                        .font(.title2.bold())
                                        .foregroundStyle(.white)
                                }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(displayName)
                                    .font(.title2.bold())
                                if !email.isEmpty {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Account card
                        profileCard(
                            title: "Account",
                            rows: ["Manage profile", "Subscription", "Connected apps"]
                        )

                        // Preferences card
                        profileCard(
                            title: "Preferences",
                            rows: ["Appearance", "Notifications", "Privacy"]
                        )

                        // Actions
                        VStack(spacing: 10) {
                            Button {
                                dismiss()
                                authService.signOut()
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Sign Out")
                                }
                                .font(.body.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Account")
                                }
                                .font(.body.weight(.medium))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        if let message = authService.errorMessage {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete Account",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    Task {
                        await authService.deleteAccount()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All your data will be permanently deleted. This cannot be undone.")
            }
        }
    }

    private func profileCard(title: String, rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            ForEach(rows, id: \.self) { row in
                HStack {
                    Text(row)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthService())
}
