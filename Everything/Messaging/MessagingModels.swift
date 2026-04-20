//
//  MessagingModels.swift
//  Everything
//

import Foundation
import FirebaseFirestore

struct AppUser: Identifiable, Equatable {
    let id: String
    var displayName: String
    var email: String
    var photoURL: String?
    var lastSeen: Date
    var isOnline: Bool

    init?(snapshot: DocumentSnapshot) {
        guard let data = snapshot.data() else { return nil }
        id = snapshot.documentID
        displayName = data["displayName"] as? String ?? "User"
        email = data["email"] as? String ?? ""
        photoURL = data["photoURL"] as? String
        lastSeen = (data["lastSeen"] as? Timestamp)?.dateValue() ?? Date()
        isOnline = data["isOnline"] as? Bool ?? false
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "displayName": displayName,
            "email": email,
            "displayNameLower": displayName.lowercased(),
            "emailLower": email.lowercased(),
            "lastSeen": Timestamp(date: Date()),
            "isOnline": true
        ]
        if let url = photoURL {
            data["photoURL"] = url
        }
        return data
    }

    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return (String(parts[0].prefix(1)) + String(parts[1].prefix(1))).uppercased()
        }
        if !displayName.isEmpty {
            return String(displayName.prefix(2)).uppercased()
        }
        return String(email.prefix(2)).uppercased()
    }

    var shortName: String {
        displayName.split(separator: " ").first.map(String.init) ?? displayName
    }

    var statusLine: String {
        if isOnline {
            return "online"
        }
        return "last seen \(lastSeen.chatStatusTimestamp)"
    }
}

struct MessageReplyPreview: Equatable {
    let messageId: String
    let senderId: String
    let text: String
}

enum MessageReaction: String, CaseIterable, Identifiable {
    case thumbsUp = "👍"
    case heart = "❤️"
    case fire = "🔥"
    case laugh = "😂"
    case celebrate = "🎉"
    case eyes = "👀"

    var id: String { rawValue }
}

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let conversationId: String
    let senderId: String
    var text: String
    var timestamp: Date
    var isRead: Bool
    var replyPreview: MessageReplyPreview?

    init?(snapshot: QueryDocumentSnapshot, conversationId: String) {
        let data = snapshot.data()
        guard let senderId = data["senderId"] as? String else { return nil }
        id = snapshot.documentID
        self.conversationId = conversationId
        self.senderId = senderId
        text = data["text"] as? String ?? ""
        timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        isRead = data["isRead"] as? Bool ?? false

        if let replyId = data["replyToMessageId"] as? String,
           let replySenderId = data["replyToSenderId"] as? String,
           let replyText = data["replyToText"] as? String {
            replyPreview = MessageReplyPreview(
                messageId: replyId,
                senderId: replySenderId,
                text: replyText
            )
        } else {
            replyPreview = nil
        }
    }
}

struct ChatConversation: Identifiable, Equatable {
    let id: String
    var participantIds: [String]
    var lastMessage: String
    var lastMessageTime: Date
    var lastMessageSenderId: String
    var unreadCounts: [String: Int]

    init?(snapshot: DocumentSnapshot) {
        guard let data = snapshot.data() else { return nil }
        id = snapshot.documentID
        participantIds = data["participantIds"] as? [String] ?? []
        guard !participantIds.isEmpty else { return nil }
        lastMessage = data["lastMessage"] as? String ?? ""
        lastMessageTime = (data["lastMessageTime"] as? Timestamp)?.dateValue() ?? Date()
        lastMessageSenderId = data["lastMessageSenderId"] as? String ?? ""
        unreadCounts = Self.parseUnreadCounts(data["unreadCounts"])
    }

    init(
        id: String,
        participantIds: [String],
        lastMessage: String,
        lastMessageTime: Date,
        lastMessageSenderId: String,
        unreadCounts: [String: Int]
    ) {
        self.id = id
        self.participantIds = participantIds
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.lastMessageSenderId = lastMessageSenderId
        self.unreadCounts = unreadCounts
    }

    var firestoreData: [String: Any] {
        [
            "participantIds": participantIds,
            "lastMessage": lastMessage,
            "lastMessageTime": Timestamp(date: lastMessageTime),
            "lastMessageSenderId": lastMessageSenderId,
            "unreadCounts": unreadCounts
        ]
    }

    func otherParticipantId(currentUserId: String) -> String? {
        participantIds.first { $0 != currentUserId }
    }

    func unreadCount(for userId: String) -> Int {
        unreadCounts[userId] ?? 0
    }

    func previewText(currentUserId: String?) -> String {
        guard !lastMessage.isEmpty else { return "No messages yet" }
        guard currentUserId == lastMessageSenderId else { return lastMessage }
        return "You: \(lastMessage)"
    }

    private static func parseUnreadCounts(_ raw: Any?) -> [String: Int] {
        if let direct = raw as? [String: Int] {
            return direct
        }
        if let numbers = raw as? [String: NSNumber] {
            return numbers.mapValues(\.intValue)
        }
        if let loose = raw as? [String: Any] {
            return loose.reduce(into: [:]) { partialResult, element in
                if let intValue = element.value as? Int {
                    partialResult[element.key] = intValue
                } else if let numberValue = element.value as? NSNumber {
                    partialResult[element.key] = numberValue.intValue
                }
            }
        }
        return [:]
    }
}

enum ChatFolder: String, CaseIterable, Identifiable {
    case all
    case unread
    case pinned
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .unread:
            return "Unread"
        case .pinned:
            return "Pinned"
        case .archived:
            return "Archive"
        }
    }

    var icon: String {
        switch self {
        case .all:
            return "bubble.left.and.bubble.right"
        case .unread:
            return "bell.badge.fill"
        case .pinned:
            return "pin.fill"
        case .archived:
            return "archivebox.fill"
        }
    }
}

struct ConversationDestination: Hashable {
    let conversationId: String
    let otherUserId: String
}

extension Date {
    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dayMonthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter
    }()

    private static let mediumFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let statusFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var chatTimeString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return Self.shortTimeFormatter.string(from: self)
        }
        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }
        if let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: Date()),
           self > sevenDaysAgo {
            return Self.weekdayFormatter.string(from: self)
        }
        return Self.dayMonthYearFormatter.string(from: self)
    }

    var chatDateSeparator: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "Today"
        }
        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }
        return Self.mediumFormatter.string(from: self)
    }

    var timeString: String {
        Self.shortTimeFormatter.string(from: self)
    }

    var chatStatusTimestamp: String {
        if Calendar.current.isDateInToday(self) {
            return "today at \(Self.shortTimeFormatter.string(from: self))"
        }
        return Self.statusFormatter.string(from: self)
    }
}
