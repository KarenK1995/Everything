//
//  NewConversationView.swift
//  Everything
//

import SwiftUI

struct NewConversationView: View {
    @EnvironmentObject private var messagingService: MessagingService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let onConversationSelected: (ConversationDestination) -> Void

    @State private var searchQuery = ""
    @State private var isCreating = false
    @FocusState private var isSearchFocused: Bool

    private var recentContacts: [AppUser] {
        messagingService.recentContacts(limit: 12)
    }

    private var sheetSurfaceFill: Color {
        colorScheme == .light ? Color.white.opacity(0.92) : TelegramTheme.surface.opacity(0.96)
    }

    private var promptSurfaceFill: Color {
        colorScheme == .light ? Color.white.opacity(0.90) : TelegramTheme.surface.opacity(0.98)
    }

    private var surfaceStroke: Color {
        colorScheme == .light ? Color.white.opacity(0.72) : TelegramTheme.separator.opacity(0.34)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TelegramListBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        searchField
                        content
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: searchQuery) { _, newValue in
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if searchQuery == newValue {
                    await messagingService.searchUsers(query: newValue)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(TelegramTheme.accentText)

            Spacer()

            Text("New Message")
                .font(.system(size: 20, weight: .semibold))

            Spacer()

            Color.clear
                .frame(width: 54, height: 1)
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search for contacts or usernames", text: $searchQuery)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(sheetSurfaceFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(surfaceStroke, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var content: some View {
        if messagingService.isSearching {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
        } else if searchQuery.isEmpty {
            defaultComposerContent
        } else if messagingService.searchResults.isEmpty {
            noResultsState
        } else {
            contactSection(title: "People", users: messagingService.searchResults)
        }
    }

    private var defaultComposerContent: some View {
        Group {
            if recentContacts.isEmpty {
                promptCard
            } else {
                contactSection(title: "Recent Chats", users: recentContacts)
            }
        }
    }

    private func contactSection(title: String, users: [AppUser]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                    ContactRowView(user: user, isCreating: isCreating) {
                        openConversation(with: user)
                    }

                    if index < users.count - 1 {
                        Divider()
                            .overlay(TelegramTheme.separator.opacity(colorScheme == .light ? 0.18 : 0.42))
                            .padding(.leading, 82)
                    }
                }
            }
            .background(sheetSurfaceFill)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(surfaceStroke, lineWidth: 1)
            }
        }
    }

    private var promptCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 42))
                .foregroundStyle(TelegramTheme.accent)

            Text("Search to start a chat")
                .font(.system(size: 21, weight: .semibold))

            Text("Type a display name or email address to open a private conversation.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(promptSurfaceFill)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(surfaceStroke, lineWidth: 1)
        }
    }

    private var noResultsState: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.quaternary)

            Text("No matches")
                .font(.system(size: 22, weight: .semibold))

            Text("No one matched \"\(searchQuery)\". Try a full name or exact email address.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(promptSurfaceFill)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(surfaceStroke, lineWidth: 1)
        }
    }

    private func openConversation(with user: AppUser) {
        guard !isCreating else { return }

        isCreating = true
        Task {
            defer { isCreating = false }

            guard let conversationId = await messagingService.findOrCreateConversation(with: user.id) else {
                return
            }

            onConversationSelected(
                ConversationDestination(conversationId: conversationId, otherUserId: user.id)
            )
        }
    }
}

private struct ContactRowView: View {
    let user: AppUser
    let isCreating: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                UserAvatarView(user: user, size: 54, showsOnlineRing: user.isOnline)

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(user.statusLine)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(user.email)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isCreating {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(isCreating)
    }
}
