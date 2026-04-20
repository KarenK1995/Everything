//
//  UserSyncService.swift
//  Everything
//

import FirebaseAuth
import FirebaseFirestore

struct UserSyncService {
    private static let db = Firestore.firestore()

    static func syncUser(_ user: FirebaseAuth.User) async {
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

        try? await db
            .collection("users")
            .document(user.uid)
            .setData(data, merge: true)
    }
}
