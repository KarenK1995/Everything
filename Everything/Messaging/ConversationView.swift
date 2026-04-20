//
//  ConversationView.swift
//  Everything
//

import SwiftUI
import UIKit

struct ConversationView: View {
    @EnvironmentObject private var messagingService: MessagingService
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let conversationId: String
    let otherUserId: String

    @State private var messageText = ""
    @State private var otherUser: AppUser?
    @State private var quotedMessage: ChatMessage?
    @FocusState private var isInputFocused: Bool

    private var messages: [ChatMessage] {
        messagingService.messagesByConversation[conversationId] ?? []
    }

    private var currentUserId: String? {
        messagingService.currentUserId
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        messageTimeline
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                TelegramThreadBackgroundView()
            }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(horizontalSizeClass == .compact)
        .toolbar {
            if horizontalSizeClass == .compact {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        TelegramGlassCircle(icon: "chevron.left", size: 40)
                    }
                    .buttonStyle(.plain)
                }
            }

            ToolbarItem(placement: .principal) {
                navigationHeader
            }

            ToolbarItem(placement: .topBarTrailing) {
                navigationAvatar
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
        }
        .task {
            messageText = messagingService.draft(for: conversationId)
            otherUser = await messagingService.fetchUser(id: otherUserId)
            messagingService.startListeningToMessages(conversationId: conversationId)
            await messagingService.markAsRead(conversationId: conversationId)
        }
        .onDisappear {
            messagingService.stopListeningToMessages(conversationId: conversationId)
            messagingService.setDraft(messageText, for: conversationId)
        }
        .onChange(of: messageText) { _, newValue in
            messagingService.setDraft(newValue, for: conversationId)
        }
    }

    private var navigationHeader: some View {
        VStack(spacing: 0) {
            Text(otherUser?.displayName ?? "Chat")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(otherUser?.statusLine ?? "Connecting")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TelegramTheme.accentText)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        }
    }

    private var navigationAvatar: some View {
        Group {
            if let otherUser {
                UserAvatarView(user: otherUser, size: 34)
            } else {
                Circle()
                    .fill(Color.white.opacity(colorScheme == .light ? 0.24 : 0.10))
                    .frame(width: 34, height: 34)
            }
        }
        .overlay {
            Circle()
                .stroke(Color.white.opacity(0.45), lineWidth: 1.5)
        }
    }

    private var messageTimeline: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        let isFromCurrentUser = message.senderId == currentUserId
                        let isGrouped = isGroupedWithPrevious(at: index)

                        VStack(spacing: 6) {
                            if shouldShowDateSeparator(at: index) {
                                dateSeparatorView(for: message.timestamp)
                            }

                            MessageBubbleView(
                                message: message,
                                isFromCurrentUser: isFromCurrentUser,
                                isGrouped: isGrouped,
                                currentUserId: currentUserId,
                                otherUser: otherUser,
                                reaction: messagingService.reaction(for: message.id),
                                onReply: {
                                    quotedMessage = message
                                    isInputFocused = true
                                },
                                onReact: { reaction in
                                    messagingService.setReaction(reaction, for: message.id)
                                }
                            )
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.22)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }

                Task {
                    await messagingService.markAsRead(conversationId: conversationId)
                }
            }
            .onAppear {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private func dateSeparatorView(for date: Date) -> some View {
        Text(date.chatDateSeparator)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(colorScheme == .light ? Color.white : Color.white.opacity(0.85))
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .background(Color.white.opacity(colorScheme == .light ? 0.20 : 0.10))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            }
            .padding(.vertical, 8)
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if let quotedMessage {
                ReplyDraftCard(
                    message: quotedMessage,
                    isFromCurrentUser: quotedMessage.senderId == currentUserId,
                    otherUser: otherUser
                ) {
                    self.quotedMessage = nil
                }
                .padding(.horizontal, 12)
            }

            HStack(alignment: .bottom, spacing: 10) {
                Menu {
                    Button(action: {}) {
                        Label("Photo", systemImage: "photo")
                    }
                    Button(action: {}) {
                        Label("File", systemImage: "doc")
                    }
                    Button(action: {}) {
                        Label("Location", systemImage: "location")
                    }
                    Button(action: {}) {
                        Label("Contact", systemImage: "person.crop.circle")
                    }
                } label: {
                    TelegramGlassCircle(
                        icon: "paperclip",
                        iconColor: TelegramTheme.accentText,
                        size: 42
                    )
                }
                .buttonStyle(.plain)

                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Message", text: $messageText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .focused($isInputFocused)
                        .lineLimit(1...6)
                        .padding(.leading, 2)

                    Button(action: {}) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .light ? 0.42 : 0.08), lineWidth: 1)
                }

                Button(action: handlePrimaryComposerAction) {
                    ZStack {
                        if canSend {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [TelegramTheme.accent, TelegramTheme.accentBright],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        } else {
                            Circle()
                                .fill(Color.white.opacity(colorScheme == .light ? 0.42 : 0.12))
                        }

                        Image(systemName: canSend ? "arrow.up" : "mic.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(canSend ? .white : .secondary)
                    }
                    .frame(width: 46, height: 46)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
    }

    private func handlePrimaryComposerAction() {
        guard canSend else {
            isInputFocused = true
            return
        }

        let text = messageText
        let replyTarget = quotedMessage
        messageText = ""
        quotedMessage = nil
        messagingService.setDraft("", for: conversationId)

        Task {
            await messagingService.sendMessage(
                text: text,
                in: conversationId,
                replyingTo: replyTarget
            )
        }
    }

    private func shouldShowDateSeparator(at index: Int) -> Bool {
        guard index < messages.count else { return false }
        if index == 0 { return true }
        return !Calendar.current.isDate(
            messages[index].timestamp,
            inSameDayAs: messages[index - 1].timestamp
        )
    }

    private func isGroupedWithPrevious(at index: Int) -> Bool {
        guard index > 0 else { return false }

        let current = messages[index]
        let previous = messages[index - 1]

        return current.senderId == previous.senderId
            && current.timestamp.timeIntervalSince(previous.timestamp) < 120
    }
}

struct MessageBubbleView: View {
    @Environment(\.colorScheme) private var colorScheme

    let message: ChatMessage
    let isFromCurrentUser: Bool
    let isGrouped: Bool
    let currentUserId: String?
    let otherUser: AppUser?
    let reaction: MessageReaction?
    let onReply: () -> Void
    let onReact: (MessageReaction?) -> Void

    private var replyAuthorName: String {
        guard let replyPreview = message.replyPreview else { return "" }
        if replyPreview.senderId == currentUserId {
            return "You"
        }
        return otherUser?.shortName ?? "Reply"
    }

    private var bubbleCornerRadii: RectangleCornerRadii {
        if isFromCurrentUser {
            return RectangleCornerRadii(
                topLeading: 20,
                bottomLeading: 20,
                bottomTrailing: 8,
                topTrailing: isGrouped ? 10 : 20
            )
        }

        return RectangleCornerRadii(
            topLeading: isGrouped ? 10 : 20,
            bottomLeading: 8,
            bottomTrailing: 20,
            topTrailing: 20
        )
    }

    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 72)
            }

            bubbleStack
                .frame(maxWidth: 320, alignment: isFromCurrentUser ? .trailing : .leading)

            if !isFromCurrentUser {
                Spacer(minLength: 72)
            }
        }
        .padding(.vertical, isGrouped ? 1 : 3)
        .contextMenu {
            Button {
                onReply()
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left.fill")
            }

            Menu("React") {
                ForEach(MessageReaction.allCases) { item in
                    Button(item.rawValue) {
                        onReact(item)
                    }
                }
            }

            Button {
                UIPasteboard.general.string = message.text
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            if reaction != nil {
                Button {
                    onReact(nil)
                } label: {
                    Label("Remove reaction", systemImage: "xmark.circle")
                }
            }
        }
    }

    private var bubbleStack: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 8) {
                if let replyPreview = message.replyPreview {
                    HStack(alignment: .top, spacing: 8) {
                        Rectangle()
                            .fill(isFromCurrentUser ? Color.white.opacity(0.72) : TelegramTheme.accent)
                            .frame(width: 3)
                            .clipShape(Capsule())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(replyAuthorName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(
                                    isFromCurrentUser
                                        ? Color.white.opacity(0.86)
                                        : TelegramTheme.accentText
                                )

                            Text(replyPreview.text)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(
                                    isFromCurrentUser
                                        ? Color.white.opacity(0.76)
                                        : .secondary
                                )
                                .lineLimit(2)
                        }
                    }
                    .padding(10)
                    .background(
                        isFromCurrentUser
                            ? Color.white.opacity(0.12)
                            : Color.black.opacity(colorScheme == .light ? 0.04 : 0.16)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Text(message.text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(isFromCurrentUser ? .white : .primary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Spacer(minLength: 0)

                    Text(message.timestamp.timeString)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isFromCurrentUser ? Color.white.opacity(0.74) : .secondary)

                    if isFromCurrentUser {
                        Image(systemName: message.isRead ? "checkmark.2" : "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(message.isRead ? Color.white.opacity(0.92) : Color.white.opacity(0.72))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(bubbleBackground)
            .clipShape(UnevenRoundedRectangle(cornerRadii: bubbleCornerRadii, style: .continuous))
            .overlay {
                if !isFromCurrentUser {
                    UnevenRoundedRectangle(cornerRadii: bubbleCornerRadii, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .light ? 0.52 : 0.08), lineWidth: 1)
                }
            }
            .shadow(color: Color.black.opacity(isFromCurrentUser ? 0.10 : 0.05), radius: 12, x: 0, y: 6)

            if let reaction {
                Button {
                    onReact(nil)
                } label: {
                    Text(reaction.rawValue)
                        .font(.system(size: 15))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.white.opacity(0.28), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bubbleBackground: some ShapeStyle {
        if isFromCurrentUser {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [TelegramTheme.accent, TelegramTheme.accentBright],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(
            colorScheme == .light
                ? TelegramTheme.incomingBubble
                : TelegramTheme.incomingBubbleDark
        )
    }
}

private struct ReplyDraftCard: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    let otherUser: AppUser?
    let onDismiss: () -> Void

    private var label: String {
        if isFromCurrentUser {
            return "Replying to yourself"
        }
        return "Replying to \(otherUser?.displayName ?? "message")"
    }

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(TelegramTheme.accent)
                .frame(width: 3)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TelegramTheme.accentText)

                Text(message.text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        }
    }
}
