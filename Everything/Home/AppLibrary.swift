//
//  AppLibrary.swift
//  Everything
//
//  Created by OpenAI Codex on 18.04.26.
//

import Combine
import Foundation
import SwiftUI

enum WorkspaceAppID: String, CaseIterable, Codable, Hashable, Identifiable {
    case chats
    case ai
    case tasks
    case calendar
    case notes
    case files

    var id: String { rawValue }
}

struct WorkspaceApp: Identifiable {
    let id: WorkspaceAppID
    let name: String
    let subtitle: String
    let description: String
    let icon: String
    let accent: [Color]
    let highlights: [String]
    let isPreinstalled: Bool
}

@MainActor
final class WorkspaceAppLibrary: ObservableObject {
    @Published private(set) var installedAppIDs: Set<WorkspaceAppID> = []

    private let defaults = UserDefaults.standard

    private enum StorageKey {
        static let installedApps = "workspace.appLibrary.installedAppIDs"
    }

    private let catalog: [WorkspaceApp] = [
        WorkspaceApp(
            id: .chats,
            name: "Chats",
            subtitle: "Messaging",
            description: "Direct messages, pinned threads, unread filters, and fast search across recent conversations.",
            icon: "bubble.left.and.bubble.right.fill",
            accent: [
                Color(red: 0.08, green: 0.37, blue: 0.68),
                Color(red: 0.13, green: 0.63, blue: 0.84)
            ],
            highlights: ["Pinned conversations", "Unread filters", "Live presence"],
            isPreinstalled: true
        ),
        WorkspaceApp(
            id: .ai,
            name: "AI",
            subtitle: "Assistant",
            description: "Prompt workflows, generated content, and AI-powered utilities for the rest of the workspace.",
            icon: "sparkles",
            accent: [
                Color(red: 0.36, green: 0.24, blue: 0.62),
                Color(red: 0.72, green: 0.36, blue: 0.47)
            ],
            highlights: ["Prompt workspace", "Generated drafts", "Tool shortcuts"],
            isPreinstalled: true
        ),
        WorkspaceApp(
            id: .tasks,
            name: "Tasks",
            subtitle: "Execution",
            description: "Collect next actions, see due work, and keep personal or team tasks moving in one place.",
            icon: "checklist.checked",
            accent: [
                Color(red: 0.86, green: 0.40, blue: 0.19),
                Color(red: 0.94, green: 0.68, blue: 0.27)
            ],
            highlights: ["Today view", "Task buckets", "Quick triage"],
            isPreinstalled: false
        ),
        WorkspaceApp(
            id: .calendar,
            name: "Calendar",
            subtitle: "Planning",
            description: "Keep upcoming meetings, deadlines, and schedule blocks aligned with the rest of your workspace.",
            icon: "calendar",
            accent: [
                Color(red: 0.02, green: 0.53, blue: 0.45),
                Color(red: 0.33, green: 0.77, blue: 0.66)
            ],
            highlights: ["Agenda focus", "Week overview", "Deadline reminders"],
            isPreinstalled: false
        ),
        WorkspaceApp(
            id: .notes,
            name: "Notes",
            subtitle: "Capture",
            description: "Save snippets, drafts, and working notes without leaving the main workspace.",
            icon: "note.text",
            accent: [
                Color(red: 0.53, green: 0.40, blue: 0.16),
                Color(red: 0.88, green: 0.74, blue: 0.45)
            ],
            highlights: ["Quick capture", "Draft boards", "Reference snippets"],
            isPreinstalled: false
        ),
        WorkspaceApp(
            id: .files,
            name: "Files",
            subtitle: "Assets",
            description: "Browse documents and uploads alongside conversations and generated content.",
            icon: "folder.fill",
            accent: [
                Color(red: 0.18, green: 0.28, blue: 0.61),
                Color(red: 0.39, green: 0.53, blue: 0.93)
            ],
            highlights: ["Recent uploads", "Shared assets", "Workspace folders"],
            isPreinstalled: false
        )
    ]

    init() {
        loadInstalledApps()
    }

    var availableApps: [WorkspaceApp] {
        catalog.filter { !installedAppIDs.contains($0.id) }
    }

    var installedApps: [WorkspaceApp] {
        catalog.filter { installedAppIDs.contains($0.id) }
    }

    var allApps: [WorkspaceApp] {
        catalog
    }

    var fixedAppIDs: Set<WorkspaceAppID> {
        Set(catalog.filter(\.isPreinstalled).map(\.id))
    }

    func app(for id: WorkspaceAppID) -> WorkspaceApp {
        catalog.first(where: { $0.id == id }) ?? catalog[0]
    }

    func isInstalled(_ app: WorkspaceApp) -> Bool {
        installedAppIDs.contains(app.id)
    }

    func install(_ app: WorkspaceApp) {
        installedAppIDs.insert(app.id)
        persistInstalledApps()
    }

    func remove(_ app: WorkspaceApp) {
        guard !app.isPreinstalled else { return }
        installedAppIDs.remove(app.id)
        persistInstalledApps()
    }

    private func loadInstalledApps() {
        let storedIDs = defaults.array(forKey: StorageKey.installedApps) as? [String] ?? []
        let installed = Set(storedIDs.compactMap(WorkspaceAppID.init(rawValue:)))
        installedAppIDs = installed.union(fixedAppIDs)
    }

    private func persistInstalledApps() {
        let persistedIDs = installedAppIDs.union(fixedAppIDs).map(\.rawValue).sorted()
        defaults.set(persistedIDs, forKey: StorageKey.installedApps)
    }
}
