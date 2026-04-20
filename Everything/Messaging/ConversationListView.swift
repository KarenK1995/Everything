//
//  ConversationListView.swift
//  Everything
//

import SwiftUI

struct ConversationListView: View {
    @EnvironmentObject private var messagingService: MessagingService
    @Environment(\.colorScheme) private var colorScheme

    @State private var navigationPath = NavigationPath()
    @State private var showNewConversation = false
    @State private var selectedFolder: ChatFolder = .all
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private var visibleConversations: [ChatConversation] {
        messagingService.conversations(in: selectedFolder, matching: searchText)
    }

    private var activeUsers: [AppUser] {
        if searchText.isEmpty {
            return messagingService.activeUsers(limit: 8)
        }
        return []
    }

    private var totalUnreadCount: Int {
        messagingService.conversations.reduce(into: 0) { partialResult, conversation in
            partialResult += messagingService.displayedUnreadCount(for: conversation)
        }
    }

    private var archiveCount: Int {
        messagingService.folderCount(.archived)
    }

    private var headerSubtitle: String {
        if !searchText.isEmpty {
            return "\(visibleConversations.count) results"
        }
        if selectedFolder != .all {
            return selectedFolder.title
        }
        if totalUnreadCount > 0 {
            return "\(totalUnreadCount) unread"
        }
        return "Synced across your devices"
    }

    private var listSurfaceFill: Color {
        colorScheme == .light ? Color.white.opacity(0.92) : TelegramTheme.surface.opacity(0.96)
    }

    private var searchFieldFill: Color {
        colorScheme == .light ? Color.white.opacity(0.88) : TelegramTheme.surface.opacity(0.98)
    }

    private var surfaceStroke: Color {
        colorScheme == .light ? Color.white.opacity(0.72) : TelegramTheme.separator.opacity(0.34)
    }

    private var surfaceShadow: Color {
        Color.black.opacity(colorScheme == .light ? 0.06 : 0.18)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                TelegramListBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        searchBar

                        if !activeUsers.isEmpty {
                            storyRail
                        }

                        folderRail

                        if archiveCount > 0 && selectedFolder != .archived && searchText.isEmpty {
                            archiveShortcut
                        }

                        conversationFeed
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showNewConversation) {
                NewConversationView { destination in
                    navigationPath.append(destination)
                    showNewConversation = false
                }
            }
            .navigationDestination(for: ConversationDestination.self) { destination in
                ConversationView(
                    conversationId: destination.conversationId,
                    otherUserId: destination.otherUserId
                )
            }
            .task {
                await messagingService.setup()
            }
            .refreshable {
                await messagingService.refresh()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            CurrentUserBadge(initials: messagingService.currentUserInitials)

            VStack(alignment: .leading, spacing: 2) {
                Text("Chats")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.primary)

                Text(headerSubtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showNewConversation = true
            } label: {
                TelegramGlassCircle(
                    icon: "square.and.pencil",
                    iconColor: TelegramTheme.accentText,
                    size: 44
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isSearchFocused = false
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
                .fill(searchFieldFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(surfaceStroke, lineWidth: 1)
        }
        .shadow(color: surfaceShadow, radius: 12, x: 0, y: 4)
    }

    private var storyRail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Stories")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(activeUsers) { user in
                        Button {
                            openConversation(with: user)
                        } label: {
                            VStack(spacing: 8) {
                                storyAvatar(for: user)

                                Text(user.shortName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                            .frame(width: 76)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func storyAvatar(for user: AppUser) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            TelegramTheme.accent,
                            TelegramTheme.accentBright
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 74, height: 74)

            Circle()
                .fill(TelegramTheme.listBackground)
                .frame(width: 68, height: 68)

            UserAvatarView(user: user, size: 62)
        }
        .shadow(color: TelegramTheme.accent.opacity(0.18), radius: 12, x: 0, y: 6)
    }

    private var folderRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ChatFolder.allCases) { folder in
                    FolderChip(
                        folder: folder,
                        count: messagingService.folderCount(folder),
                        isSelected: selectedFolder == folder
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            selectedFolder = folder
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var archiveShortcut: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selectedFolder = .archived
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(TelegramTheme.searchFill)
                        .frame(width: 40, height: 40)

                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TelegramTheme.accentText)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Archived Chats")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("Hidden from the main list")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                UnreadBadge(count: archiveCount, isMuted: false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(listSurfaceFill)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(surfaceStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var conversationFeed: some View {
        if messagingService.isLoadingConversations && messagingService.conversations.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 56)
        } else if visibleConversations.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                ForEach(Array(visibleConversations.enumerated()), id: \.element.id) { index, conversation in
                    ConversationCardView(
                        conversation: conversation,
                        user: messagingService.conversationPartner(for: conversation),
                        unreadCount: messagingService.displayedUnreadCount(for: conversation),
                        isPinned: messagingService.isPinned(conversation.id),
                        isMuted: messagingService.isMuted(conversation.id),
                        isArchived: messagingService.isArchived(conversation.id),
                        currentUserId: messagingService.currentUserId,
                        draftText: messagingService.draft(for: conversation.id),
                        onOpen: { openConversation(conversation) },
                        onTogglePinned: { messagingService.togglePinned(conversationId: conversation.id) },
                        onToggleMuted: { messagingService.toggleMuted(conversationId: conversation.id) },
                        onToggleArchived: { messagingService.toggleArchived(conversationId: conversation.id) },
                        onToggleRead: { messagingService.toggleReadState(for: conversation) }
                    )

                    if index < visibleConversations.count - 1 {
                        Divider()
                            .overlay(TelegramTheme.separator.opacity(colorScheme == .light ? 0.18 : 0.42))
                            .padding(.leading, 84)
                    }
                }
            }
            .background(listSurfaceFill)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(surfaceStroke, lineWidth: 1)
            }
            .shadow(color: surfaceShadow, radius: 18, x: 0, y: 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: searchText.isEmpty ? "bubble.left.and.bubble.right.fill" : "magnifyingglass.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.quaternary)

            Text(searchText.isEmpty ? "No chats yet" : "No results")
                .font(.system(size: 22, weight: .semibold))

            Text(
                searchText.isEmpty
                    ? "Start a new conversation and it will appear here."
                    : "Try another name, email, or phrase from a recent message."
            )
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(listSurfaceFill)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(surfaceStroke, lineWidth: 1)
        }
    }

    private func openConversation(_ conversation: ChatConversation) {
        guard
            let currentId = messagingService.currentUserId,
            let otherUserId = conversation.otherParticipantId(currentUserId: currentId)
        else {
            return
        }

        navigationPath.append(
            ConversationDestination(conversationId: conversation.id, otherUserId: otherUserId)
        )
    }

    private func openConversation(with user: AppUser) {
        Task {
            guard let conversationId = await messagingService.findOrCreateConversation(with: user.id) else {
                return
            }
            navigationPath.append(
                ConversationDestination(conversationId: conversationId, otherUserId: user.id)
            )
        }
    }
}

struct ConversationCardView: View {
    let conversation: ChatConversation
    let user: AppUser?
    let unreadCount: Int
    let isPinned: Bool
    let isMuted: Bool
    let isArchived: Bool
    let currentUserId: String?
    let draftText: String
    let onOpen: () -> Void
    let onTogglePinned: () -> Void
    let onToggleMuted: () -> Void
    let onToggleArchived: () -> Void
    let onToggleRead: () -> Void

    private var isLastMessageFromCurrentUser: Bool {
        conversation.lastMessageSenderId == currentUserId
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 12) {
                if let user {
                    UserAvatarView(user: user, size: 56, showsOnlineRing: user.isOnline)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.18))
                        .frame(width: 56, height: 56)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(user?.displayName ?? "Loading…")
                            .font(.system(size: 17, weight: unreadCount > 0 ? .semibold : .regular))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(conversation.lastMessageTime.chatTimeString)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(unreadCount > 0 ? TelegramTheme.accentText : .secondary)
                    }

                    HStack(alignment: .center, spacing: 6) {
                        if draftText.isEmpty {
                            if isLastMessageFromCurrentUser {
                                Image(systemName: "checkmark.2")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(TelegramTheme.accentText)
                            }

                            Text(conversation.previewText(currentUserId: currentUserId))
                                .font(.system(size: 15, weight: unreadCount > 0 ? .semibold : .regular))
                                .foregroundStyle(unreadCount > 0 ? .primary : .secondary)
                                .lineLimit(1)
                        } else {
                            Text("Draft")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(TelegramTheme.draft)

                            Text(draftText)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        HStack(spacing: 6) {
                            if isArchived {
                                Image(systemName: "archivebox.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }

                            if isMuted {
                                Image(systemName: "bell.slash.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }

                            if unreadCount > 0 {
                                UnreadBadge(count: unreadCount, isMuted: isMuted)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(isPinned ? "Unpin" : "Pin") { onTogglePinned() }
            Button(isMuted ? "Unmute" : "Mute") { onToggleMuted() }
            Button(isArchived ? "Return to inbox" : "Archive") { onToggleArchived() }
            Button(unreadCount > 0 ? "Mark as read" : "Mark as unread") { onToggleRead() }
        }
    }
}

struct UserAvatarView: View {
    let user: AppUser
    let size: CGFloat
    var showsOnlineRing: Bool = false

    private static let palette: [Color] = [
        Color(red: 0.94, green: 0.46, blue: 0.30),
        Color(red: 0.23, green: 0.55, blue: 0.92),
        Color(red: 0.17, green: 0.71, blue: 0.56),
        Color(red: 0.76, green: 0.45, blue: 0.93),
        Color(red: 0.98, green: 0.52, blue: 0.62),
        Color(red: 0.18, green: 0.73, blue: 0.86),
        Color(red: 0.93, green: 0.65, blue: 0.24),
        Color(red: 0.41, green: 0.54, blue: 0.98)
    ]

    private var backgroundColor: Color {
        Self.palette[abs(user.id.hashValue) % Self.palette.count]
    }

    private var onlineDotSize: CGFloat {
        max(10, size * 0.26)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            backgroundColor.opacity(0.88),
                            backgroundColor
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(user.initials)
                .font(.system(size: size * 0.34, weight: .black))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if showsOnlineRing {
                Circle()
                    .fill(TelegramTheme.success)
                    .frame(width: onlineDotSize, height: onlineDotSize)
                    .overlay {
                        Circle()
                            .stroke(Color.white, lineWidth: max(2, size * 0.06))
                    }
            }
        }
    }
}

private struct FolderChip: View {
    @Environment(\.colorScheme) private var colorScheme

    let folder: ChatFolder
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(folder.title)
                    .font(.system(size: 14, weight: .semibold))

                if count > 0 {
                    Text(count > 99 ? "99+" : "\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(isSelected ? Color.white.opacity(0.18) : TelegramTheme.searchFill)
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [TelegramTheme.accent, TelegramTheme.accentBright],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        TelegramTheme.surface.opacity(colorScheme == .light ? 0.90 : 0.98)
                    }
                }
            )
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(
                        isSelected
                            ? Color.white.opacity(0.16)
                            : TelegramTheme.separator.opacity(colorScheme == .light ? 0.22 : 0.34),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CurrentUserBadge: View {
    let initials: String

    var body: some View {
        Text(initials)
            .font(.system(size: 16, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 50, height: 50)
            .background(
                LinearGradient(
                    colors: [TelegramTheme.accent, TelegramTheme.accentBright],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
            .shadow(color: TelegramTheme.accent.opacity(0.25), radius: 12, x: 0, y: 6)
    }
}

private struct UnreadBadge: View {
    let count: Int
    let isMuted: Bool

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(minWidth: 22)
            .padding(.horizontal, count > 9 ? 7 : 0)
            .padding(.vertical, 4)
            .background(isMuted ? Color.gray : TelegramTheme.accent)
            .clipShape(Capsule())
    }
}
