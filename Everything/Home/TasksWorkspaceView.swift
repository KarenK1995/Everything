//
//  TasksWorkspaceView.swift
//  Everything
//
//  Created by OpenAI Codex on 20.04.26.
//

import Foundation
import SwiftUI

struct TaskItem: Identifiable, Codable, Equatable {
    enum Priority: String, CaseIterable, Codable, Identifiable {
        case low
        case medium
        case high

        var id: String { rawValue }

        var title: String {
            switch self {
            case .low:
                return "Low"
            case .medium:
                return "Medium"
            case .high:
                return "High"
            }
        }

        var color: Color {
            switch self {
            case .low:
                return .green
            case .medium:
                return .orange
            case .high:
                return .red
            }
        }
    }

    var id: UUID
    var title: String
    var dueDate: Date
    var isDone: Bool
    var priority: Priority
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date = Date(),
        isDone: Bool = false,
        priority: Priority = .medium,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isDone = isDone
        self.priority = priority
        self.createdAt = createdAt
    }
}

@MainActor
final class TasksStore: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum StorageKey {
        static let tasks = "workspace.tasks.items"
    }

    init() {
        load()
    }

    var openTasks: [TaskItem] {
        tasks
            .filter { !$0.isDone }
            .sorted {
                if Calendar.current.isDate($0.dueDate, inSameDayAs: $1.dueDate) {
                    return $0.createdAt < $1.createdAt
                }
                return $0.dueDate < $1.dueDate
            }
    }

    var completedTasks: [TaskItem] {
        tasks
            .filter(\.isDone)
            .sorted { $0.dueDate > $1.dueDate }
    }

    func addTask(title: String, dueDate: Date, priority: TaskItem.Priority) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tasks.append(TaskItem(title: trimmed, dueDate: dueDate, priority: priority))
        persist()
    }

    func toggle(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isDone.toggle()
        persist()
    }

    func updatePriority(_ priority: TaskItem.Priority, for task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].priority = priority
        persist()
    }

    func delete(at offsets: IndexSet, inCompletedSection: Bool) {
        let source = inCompletedSection ? completedTasks : openTasks
        let idsToDelete = offsets.map { source[$0].id }
        tasks.removeAll { idsToDelete.contains($0.id) }
        persist()
    }

    private func load() {
        guard
            let data = defaults.data(forKey: StorageKey.tasks),
            let decoded = try? decoder.decode([TaskItem].self, from: data)
        else {
            tasks = []
            return
        }
        tasks = decoded
    }

    private func persist() {
        guard let data = try? encoder.encode(tasks) else { return }
        defaults.set(data, forKey: StorageKey.tasks)
    }
}

struct TasksWorkspaceView: View {
    @StateObject private var store = TasksStore()
    @State private var draftTitle = ""
    @State private var draftPriority: TaskItem.Priority = .medium
    @State private var draftDate = Date()

    private var todaysCount: Int {
        store.openTasks.filter { Calendar.current.isDateInToday($0.dueDate) }.count
    }

    var body: some View {
        List {
            metricsSection
            addSection
            openTasksSection
            if !store.completedTasks.isEmpty {
                completedTasksSection
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .navigationTitle("Tasks")
    }

    private var metricsSection: some View {
        Section {
            HStack(spacing: 12) {
                taskMetric(title: "Open", value: "\(store.openTasks.count)", icon: "list.bullet")
                taskMetric(title: "Today", value: "\(todaysCount)", icon: "sun.max.fill")
                taskMetric(title: "Done", value: "\(store.completedTasks.count)", icon: "checkmark.seal.fill")
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
        }
    }

    private var addSection: some View {
        Section("Quick Add") {
            TextField("What needs to happen?", text: $draftTitle)

            DatePicker("Due", selection: $draftDate, displayedComponents: [.date, .hourAndMinute])

            Picker("Priority", selection: $draftPriority) {
                ForEach(TaskItem.Priority.allCases) { priority in
                    Text(priority.title).tag(priority)
                }
            }
            .pickerStyle(.segmented)

            Button {
                store.addTask(title: draftTitle, dueDate: draftDate, priority: draftPriority)
                draftTitle = ""
                draftDate = Date()
                draftPriority = .medium
            } label: {
                Label("Add Task", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var openTasksSection: some View {
        Section("Open Tasks") {
            if store.openTasks.isEmpty {
                Text("No open tasks yet. Add your first one above.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.openTasks) { task in
                    TaskRowView(task: task, onToggle: { store.toggle(task) }) { priority in
                        store.updatePriority(priority, for: task)
                    }
                }
                .onDelete { offsets in
                    store.delete(at: offsets, inCompletedSection: false)
                }
            }
        }
    }

    private var completedTasksSection: some View {
        Section("Completed") {
            ForEach(store.completedTasks) { task in
                TaskRowView(task: task, onToggle: { store.toggle(task) }) { priority in
                    store.updatePriority(priority, for: task)
                }
            }
            .onDelete { offsets in
                store.delete(at: offsets, inCompletedSection: true)
            }
        }
    }

    private func taskMetric(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct TaskRowView: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onPriorityChange: (TaskItem.Priority) -> Void

    private var dueDateText: String {
        task.dueDate.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(task.isDone ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.body.weight(.semibold))
                    .strikethrough(task.isDone, color: .secondary)
                Text(dueDateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                ForEach(TaskItem.Priority.allCases) { priority in
                    Button(priority.title) {
                        onPriorityChange(priority)
                    }
                }
            } label: {
                Text(task.priority.title)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(task.priority.color.opacity(0.15), in: Capsule())
                    .foregroundStyle(task.priority.color)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TasksWorkspaceView()
    }
}
