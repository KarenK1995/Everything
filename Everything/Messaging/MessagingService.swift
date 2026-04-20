//
//  MessagingService.swift
//  Everything
//

import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class MessagingService: ObservableObject {
    @Published var conversations: [ChatConversation] = []
    @Published var messagesByConversation: [String: [ChatMessage]] = [:]
    @Published var cachedUsers: [String: AppUser] = [:]
    @Published var isLoadingConversations = false
    @Published var searchResults: [AppUser] = []
    @Published var isSearching = false
    @Published private(set) var pinnedConversationIds: Set<String> = []
    @Published private(set) var mutedConversationIds: Set<String> = []
    @Published private(set) var archivedConversationIds: Set<String> = []
    @Published private(set) var manualUnreadConversationIds: Set<String> = []
    @Published private(set) var draftTexts: [String: String] = [:]
    @Published private(set) var reactionsByMessageId: [String: String] = [:]

    private let db = Firestore.firestore()
    private let defaults = UserDefaults.standard
    private var conversationListener: ListenerRegistration?
    private var messageListeners: [String: ListenerRegistration] = [:]

    private enum StorageKey {
        static let pinned = "messaging.local.pinnedConversationIds"
        static let muted = "messaging.local.mutedConversationIds"
        static let archived = "messaging.local.archivedConversationIds"
        static let manualUnread = "messaging.local.manualUnreadConversationIds"
        static let drafts = "messaging.local.draftTexts"
        static let reactions = "messaging.local.reactionsByMessageId"
    }

    init() {
        loadLocalState()
    }

    var currentUserId: String? { Auth.auth().currentUser?.uid }

    var currentUserDisplayName: String {
        if let displayName = Auth.auth().currentUser?.displayName,
           !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return displayName
        }
        if let email = Auth.auth().currentUser?.email,
           let name = email.split(separator: "@").first {
            return String(name)
        }
        return "You"
    }

    var currentUserInitials: String {
        let parts = currentUserDisplayName.split(separator: " ")
        if parts.count >= 2 {
            return (String(parts[0].prefix(1)) + String(parts[1].prefix(1))).uppercased()
        }
        return String(currentUserDisplayName.prefix(2)).uppercased()
    }

    func setup() async {
        await upsertCurrentUser()
        startListeningToConversations()
    }

    func fetchUser(id: String) async -> AppUser? {
        if let cached = cachedUsers[id] {
            return cached
        }
        guard
            let snapshot = try? await db.collection("users").document(id).getDocument(),
            let user = AppUser(snapshot: snapshot)
        else {
            return nil
        }
        cachedUsers[id] = user
        return user
    }

    func searchUsers(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        let lower = trimmed.lowercased()
        let currentId = currentUserId

        let nameSnapshot = try? await db.collection("users")
            .whereField("displayNameLower", isGreaterThanOrEqualTo: lower)
            .whereField("displayNameLower", isLessThan: lower + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments()

        let emailSnapshot = try? await db.collection("users")
            .whereField("emailLower", isGreaterThanOrEqualTo: lower)
            .whereField("emailLower", isLessThan: lower + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments()

        let allDocuments = (nameSnapshot?.documents ?? []) + (emailSnapshot?.documents ?? [])
        var seenIds = Set<String>()
        var users: [AppUser] = []

        for document in allDocuments {
            guard
                !seenIds.contains(document.documentID),
                let user = AppUser(snapshot: document),
                user.id != currentId
            else {
                continue
            }
            users.append(user)
            seenIds.insert(document.documentID)
            cachedUsers[user.id] = user
        }

        searchResults = users.sorted { lhs, rhs in
            if lhs.isOnline != rhs.isOnline {
                return lhs.isOnline && !rhs.isOnline
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    func conversationPartner(for conversation: ChatConversation) -> AppUser? {
        guard
            let currentId = currentUserId,
            let otherUserId = conversation.otherParticipantId(currentUserId: currentId)
        else {
            return nil
        }
        return cachedUsers[otherUserId]
    }

    func recentContacts(limit: Int = 8) -> [AppUser] {
        guard let currentId = currentUserId else { return [] }
        let users = conversations.compactMap { conversation -> AppUser? in
            guard let otherUserId = conversation.otherParticipantId(currentUserId: currentId) else {
                return nil
            }
            return cachedUsers[otherUserId]
        }

        let sorted = users.sorted { lhs, rhs in
            if lhs.isOnline != rhs.isOnline {
                return lhs.isOnline && !rhs.isOnline
            }
            return lhs.lastSeen > rhs.lastSeen
        }
        return Array(sorted.prefix(limit))
    }

    func activeUsers(limit: Int = 8) -> [AppUser] {
        recentContacts(limit: limit).filter(\.isOnline)
    }

    func conversations(in folder: ChatFolder, matching searchText: String = "") -> [ChatConversation] {
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered = conversations.filter { conversation in
            let isArchived = archivedConversationIds.contains(conversation.id)

            switch folder {
            case .all:
                return !isArchived
            case .unread:
                return !isArchived && displayedUnreadCount(for: conversation) > 0
            case .pinned:
                return !isArchived && pinnedConversationIds.contains(conversation.id)
            case .archived:
                return isArchived
            }
        }

        let searched = filtered.filter { conversation in
            guard !normalizedSearch.isEmpty else { return true }
            if conversation.lastMessage.localizedCaseInsensitiveContains(normalizedSearch) {
                return true
            }
            guard let user = conversationPartner(for: conversation) else { return false }
            return user.displayName.localizedCaseInsensitiveContains(normalizedSearch)
                || user.email.localizedCaseInsensitiveContains(normalizedSearch)
        }

        return searched.sorted { lhs, rhs in
            let lhsPinned = pinnedConversationIds.contains(lhs.id) && !archivedConversationIds.contains(lhs.id)
            let rhsPinned = pinnedConversationIds.contains(rhs.id) && !archivedConversationIds.contains(rhs.id)
            if lhsPinned != rhsPinned {
                return lhsPinned && !rhsPinned
            }
            return lhs.lastMessageTime > rhs.lastMessageTime
        }
    }

    func folderCount(_ folder: ChatFolder) -> Int {
        conversations(in: folder).count
    }

    func displayedUnreadCount(for conversation: ChatConversation) -> Int {
        guard let currentId = currentUserId else { return 0 }
        let serverCount = conversation.unreadCount(for: currentId)
        if serverCount == 0 && manualUnreadConversationIds.contains(conversation.id) {
            return 1
        }
        return serverCount
    }

    func isPinned(_ conversationId: String) -> Bool {
        pinnedConversationIds.contains(conversationId)
    }

    func isMuted(_ conversationId: String) -> Bool {
        mutedConversationIds.contains(conversationId)
    }

    func isArchived(_ conversationId: String) -> Bool {
        archivedConversationIds.contains(conversationId)
    }

    func togglePinned(conversationId: String) {
        if pinnedConversationIds.contains(conversationId) {
            pinnedConversationIds.remove(conversationId)
        } else {
            pinnedConversationIds.insert(conversationId)
        }
        persistSet(pinnedConversationIds, key: StorageKey.pinned)
    }

    func toggleMuted(conversationId: String) {
        if mutedConversationIds.contains(conversationId) {
            mutedConversationIds.remove(conversationId)
        } else {
            mutedConversationIds.insert(conversationId)
        }
        persistSet(mutedConversationIds, key: StorageKey.muted)
    }

    func toggleArchived(conversationId: String) {
        if archivedConversationIds.contains(conversationId) {
            archivedConversationIds.remove(conversationId)
        } else {
            archivedConversationIds.insert(conversationId)
        }
        persistSet(archivedConversationIds, key: StorageKey.archived)
    }

    func toggleReadState(for conversation: ChatConversation) {
        if displayedUnreadCount(for: conversation) > 0 {
            manualUnreadConversationIds.remove(conversation.id)
            persistSet(manualUnreadConversationIds, key: StorageKey.manualUnread)
            Task {
                await markAsRead(conversationId: conversation.id)
            }
            return
        }

        manualUnreadConversationIds.insert(conversation.id)
        persistSet(manualUnreadConversationIds, key: StorageKey.manualUnread)
    }

    func draft(for conversationId: String) -> String {
        draftTexts[conversationId] ?? ""
    }

    func setDraft(_ text: String, for conversationId: String) {
        if text.isEmpty {
            draftTexts.removeValue(forKey: conversationId)
        } else {
            draftTexts[conversationId] = text
        }
        defaults.set(draftTexts, forKey: StorageKey.drafts)
    }

    func reaction(for messageId: String) -> MessageReaction? {
        guard let value = reactionsByMessageId[messageId] else { return nil }
        return MessageReaction(rawValue: value)
    }

    func setReaction(_ reaction: MessageReaction?, for messageId: String) {
        if let reaction {
            reactionsByMessageId[messageId] = reaction.rawValue
        } else {
            reactionsByMessageId.removeValue(forKey: messageId)
        }
        defaults.set(reactionsByMessageId, forKey: StorageKey.reactions)
    }

    func refresh() async {
        await upsertCurrentUser()
    }

    func startListeningToConversations() {
        guard let userId = currentUserId else { return }
        conversationListener?.remove()
        isLoadingConversations = true

        conversationListener = db.collection("messaging_conversations")
            .whereField("participantIds", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    self.isLoadingConversations = false
                    guard let documents = snapshot?.documents else {
                        self.conversations = []
                        return
                    }

                    let loadedConversations = documents.compactMap { ChatConversation(snapshot: $0) }
                    self.conversations = loadedConversations
                    await self.preloadUsers(for: loadedConversations)
                }
            }
    }

    func findOrCreateConversation(with otherUserId: String) async -> String? {
        guard let currentId = currentUserId else { return nil }

        let snapshot = try? await db.collection("messaging_conversations")
            .whereField("participantIds", arrayContains: currentId)
            .getDocuments()

        if let existingConversation = snapshot?.documents
            .compactMap({ ChatConversation(snapshot: $0) })
            .first(where: {
                $0.participantIds.count == 2 && $0.participantIds.contains(otherUserId)
            }) {
            archivedConversationIds.remove(existingConversation.id)
            persistSet(archivedConversationIds, key: StorageKey.archived)
            return existingConversation.id
        }

        let conversationRef = db.collection("messaging_conversations").document()
        let conversation = ChatConversation(
            id: conversationRef.documentID,
            participantIds: [currentId, otherUserId],
            lastMessage: "",
            lastMessageTime: Date(),
            lastMessageSenderId: currentId,
            unreadCounts: [currentId: 0, otherUserId: 0]
        )

        try? await conversationRef.setData(conversation.firestoreData)
        archivedConversationIds.remove(conversationRef.documentID)
        persistSet(archivedConversationIds, key: StorageKey.archived)
        return conversationRef.documentID
    }

    func startListeningToMessages(conversationId: String) {
        guard messageListeners[conversationId] == nil else { return }

        let listener = db.collection("messaging_conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let documents = snapshot?.documents else { return }
                Task { @MainActor in
                    self.messagesByConversation[conversationId] = documents.compactMap {
                        ChatMessage(snapshot: $0, conversationId: conversationId)
                    }
                }
            }

        messageListeners[conversationId] = listener
    }

    func stopListeningToMessages(conversationId: String) {
        messageListeners[conversationId]?.remove()
        messageListeners.removeValue(forKey: conversationId)
    }

    func sendMessage(text: String, in conversationId: String, replyingTo: ChatMessage? = nil) async {
        guard
            let currentId = currentUserId,
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let conversationRef = db.collection("messaging_conversations").document(conversationId)

        let conversationSnapshot = try? await conversationRef.getDocument()
        let otherUserId = conversationSnapshot
            .flatMap { ChatConversation(snapshot: $0) }
            .flatMap { $0.otherParticipantId(currentUserId: currentId) } ?? ""

        let messageRef = conversationRef.collection("messages").document()
        var payload: [String: Any] = [
            "senderId": currentId,
            "text": trimmedText,
            "timestamp": Timestamp(date: Date()),
            "isRead": false
        ]

        if let replyingTo {
            payload["replyToMessageId"] = replyingTo.id
            payload["replyToSenderId"] = replyingTo.senderId
            payload["replyToText"] = replyingTo.text
        }

        let batch = db.batch()
        batch.setData(payload, forDocument: messageRef)
        batch.updateData([
            "lastMessage": trimmedText,
            "lastMessageTime": Timestamp(date: Date()),
            "lastMessageSenderId": currentId,
            "unreadCounts.\(otherUserId)": FieldValue.increment(Int64(1))
        ], forDocument: conversationRef)

        try? await batch.commit()

        manualUnreadConversationIds.remove(conversationId)
        persistSet(manualUnreadConversationIds, key: StorageKey.manualUnread)
        archivedConversationIds.remove(conversationId)
        persistSet(archivedConversationIds, key: StorageKey.archived)
    }

    func markAsRead(conversationId: String) async {
        guard let currentId = currentUserId else { return }

        let conversationRef = db.collection("messaging_conversations").document(conversationId)
        try? await conversationRef.updateData(["unreadCounts.\(currentId)": 0])

        let snapshot = try? await conversationRef.collection("messages").getDocuments()
        if let documents = snapshot?.documents {
            let batch = db.batch()
            var hasPendingUpdates = false

            for document in documents {
                let data = document.data()
                let senderId = data["senderId"] as? String ?? ""
                let isRead = data["isRead"] as? Bool ?? false
                guard senderId != currentId, !isRead else { continue }

                batch.updateData(["isRead": true], forDocument: document.reference)
                hasPendingUpdates = true
            }

            if hasPendingUpdates {
                try? await batch.commit()
            }
        }

        manualUnreadConversationIds.remove(conversationId)
        persistSet(manualUnreadConversationIds, key: StorageKey.manualUnread)
    }

    private func upsertCurrentUser() async {
        guard let user = Auth.auth().currentUser else { return }

        let displayName = user.displayName
            ?? user.email?.components(separatedBy: "@").first
            ?? "User"

        var data: [String: Any] = [
            "displayName": displayName,
            "email": user.email ?? "",
            "displayNameLower": displayName.lowercased(),
            "emailLower": (user.email ?? "").lowercased(),
            "lastSeen": Timestamp(date: Date()),
            "isOnline": true
        ]

        if let photoURL = user.photoURL?.absoluteString {
            data["photoURL"] = photoURL
        }

        try? await db.collection("users")
            .document(user.uid)
            .setData(data, merge: true)
    }

    private func preloadUsers(for conversations: [ChatConversation]) async {
        guard let currentId = currentUserId else { return }

        let userIds = Set(conversations.compactMap { $0.otherParticipantId(currentUserId: currentId) })
        for userId in userIds where cachedUsers[userId] == nil {
            _ = await fetchUser(id: userId)
        }
    }

    private func loadLocalState() {
        pinnedConversationIds = Set(defaults.stringArray(forKey: StorageKey.pinned) ?? [])
        mutedConversationIds = Set(defaults.stringArray(forKey: StorageKey.muted) ?? [])
        archivedConversationIds = Set(defaults.stringArray(forKey: StorageKey.archived) ?? [])
        manualUnreadConversationIds = Set(defaults.stringArray(forKey: StorageKey.manualUnread) ?? [])
        draftTexts = defaults.dictionary(forKey: StorageKey.drafts) as? [String: String] ?? [:]
        reactionsByMessageId = defaults.dictionary(forKey: StorageKey.reactions) as? [String: String] ?? [:]
    }

    private func persistSet(_ value: Set<String>, key: String) {
        defaults.set(Array(value), forKey: key)
    }
}
