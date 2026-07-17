//
//  TasksView.swift
//  Cadence
//

import SwiftData
import SwiftUI

enum TaskSmartList: String, CaseIterable, Identifiable {
    case myDay
    case upcoming
    case all
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .myDay: return "My Day"
        case .upcoming: return "Upcoming"
        case .all: return "All Tasks"
        case .completed: return "Completed"
        }
    }

    var symbolName: String {
        switch self {
        case .myDay: return "sun.max.fill"
        case .upcoming: return "calendar.badge.clock"
        case .all: return "tray.full.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }

    var emptyTitle: String {
        switch self {
        case .myDay: return "You're all caught up."
        case .upcoming: return "Nothing due soon."
        case .all: return "No tasks yet."
        case .completed: return "No completed tasks."
        }
    }

    var emptyMessage: String {
        switch self {
        case .myDay: return "Add something for today, or enjoy the open space."
        case .upcoming: return "Tasks with due dates will collect here automatically."
        case .all: return "Capture a task and Cadence will keep it close."
        case .completed: return "Finished tasks appear here when you check them off."
        }
    }
}

enum TaskListScope: Equatable {
    case smart(TaskSmartList)
    case custom(UUID, String)

    var title: String {
        switch self {
        case .smart(let smartList): return smartList.title
        case .custom(_, let name): return name
        }
    }

    var symbolName: String {
        switch self {
        case .smart(let smartList): return smartList.symbolName
        case .custom: return "list.bullet.rectangle.fill"
        }
    }
}

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskList.sortIndex) private var lists: [TaskList]
    @Query(sort: \CadenceTask.createdAt, order: .reverse) private var tasks: [CadenceTask]

    @State private var showTaskEditor = false
    @State private var showNewListAlert = false
    @State private var newListName = ""
    @State private var listToRename: TaskList?
    @State private var renameListName = ""

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var summary: TaskDashboardSummary {
        TaskDashboardSummary(tasks: tasks, today: today)
    }

    var body: some View {
        let dashboardSummary = summary

        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Theme.background.ignoresSafeArea()
                Theme.glow.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header(summary: dashboardSummary)
                        smartLists(summary: dashboardSummary)
                        customLists(summary: dashboardSummary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 112)
                }

                addButton
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showTaskEditor) {
                TaskEditorView(task: nil, preferredListId: lists.first?.id)
            }
            .alert("New List", isPresented: $showNewListAlert) {
                TextField("List name", text: $newListName)
                Button("Cancel", role: .cancel) { newListName = "" }
                Button("Create") { createList() }
                    .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Create a focused place for related tasks.")
            }
            .alert("Rename List", isPresented: renameAlertBinding) {
                TextField("List name", text: $renameListName)
                Button("Cancel", role: .cancel) { clearRenameState() }
                Button("Save") { renameList() }
                    .disabled(renameListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .task {
                TaskSeedService.seedDefaultListsIfNeeded(in: modelContext)
            }
        }
    }

    private func header(summary: TaskDashboardSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tasks")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            Text("\(summary.openCount) open • \(summary.completedCount) completed")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.accent)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func smartLists(summary: TaskDashboardSummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(TaskSmartList.allCases) { smartList in
                NavigationLink {
                    TaskListDetailView(scope: .smart(smartList))
                } label: {
                    smartListCard(smartList, count: summary.smartCounts[smartList, default: 0])
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.97))
            }
        }
    }

    private func smartListCard(_ smartList: TaskSmartList, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: smartList.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color(for: smartList))
                    .frame(width: 38, height: 38)
                    .background(color(for: smartList).opacity(0.13), in: .circle)

                Spacer()

                Text("\(count)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
            }

            Text(smartList.title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceGradient, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.strokeSoft, lineWidth: 1)
        )
    }

    private func customLists(summary: TaskDashboardSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Lists")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .textCase(.uppercase)

                Spacer()

                Button {
                    newListName = ""
                    showNewListAlert = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 30, height: 30)
                        .background(Theme.accentSoft, in: .circle)
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.9))
                .accessibilityLabel("Create list")
            }

            if lists.isEmpty {
                emptyLists
            } else {
                VStack(spacing: 8) {
                    ForEach(lists) { list in
                        NavigationLink {
                            TaskListDetailView(scope: .custom(list.id, list.name))
                        } label: {
                            customListRow(list, count: summary.openCountsByListId[list.id, default: 0])
                        }
                        .buttonStyle(PressScaleButtonStyle(scale: 0.98))
                        .contextMenu {
                            Button {
                                beginRename(list)
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }

                            Button {
                                moveList(list, direction: -1)
                            } label: {
                                Label("Move Up", systemImage: "arrow.up")
                            }
                            .disabled(isFirstList(list))

                            Button {
                                moveList(list, direction: 1)
                            } label: {
                                Label("Move Down", systemImage: "arrow.down")
                            }
                            .disabled(isLastList(list))

                            Button(role: .destructive) {
                                deleteList(list)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private func customListRow(_ list: TaskList, count: Int) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "list.bullet.rectangle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.coolAccent)
                .frame(width: 36, height: 36)
                .background(Theme.coolAccent.opacity(0.13), in: .circle)

            Text(list.name)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Text("\(count)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(14)
        .background(Theme.surface, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.strokeSoft, lineWidth: 1)
        )
    }

    private var emptyLists: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.accent)

            Text("Create your first list.")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            Button("New List") {
                showNewListAlert = true
            }
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.accentGradient, in: .capsule)
            .buttonStyle(PressScaleButtonStyle(scale: 0.94))
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(Theme.surface, in: .rect(cornerRadius: 18))
    }

    private var addButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showTaskEditor = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 62, height: 62)
                .background(Theme.accentGradient, in: .circle)
                .shadow(color: Theme.accent.opacity(0.45), radius: 18, y: 8)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Add task")
        .padding(.trailing, 22)
        .padding(.bottom, 28)
    }

    private func color(for smartList: TaskSmartList) -> Color {
        switch smartList {
        case .myDay: return Theme.accent
        case .upcoming: return Theme.coolAccent
        case .all: return Color(hex: 0xB6A7FF)
        case .completed: return Color(hex: 0x7BD88F)
        }
    }

    private func createList() {
        let trimmed = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(TaskList(name: trimmed, sortIndex: lists.count))
        try? modelContext.save()
        newListName = ""
    }

    private func beginRename(_ list: TaskList) {
        listToRename = list
        renameListName = list.name
    }

    private func renameList() {
        guard let listToRename else { return }
        let trimmed = renameListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        listToRename.name = trimmed
        listToRename.updatedAt = Date()
        try? modelContext.save()
        clearRenameState()
    }

    private func clearRenameState() {
        listToRename = nil
        renameListName = ""
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { listToRename != nil },
            set: { isPresented in
                if !isPresented {
                    clearRenameState()
                }
            }
        )
    }

    private func deleteList(_ list: TaskList) {
        for task in tasks where task.listId == list.id {
            task.listId = lists.first(where: { $0.id != list.id })?.id
            task.updatedAt = Date()
        }
        modelContext.delete(list)
        normalizeListOrder()
        try? modelContext.save()
    }

    private func moveList(_ list: TaskList, direction: Int) {
        guard let currentIndex = lists.firstIndex(where: { $0.id == list.id }) else { return }
        let newIndex = currentIndex + direction
        guard lists.indices.contains(newIndex) else { return }

        var reordered = lists
        reordered.swapAt(currentIndex, newIndex)

        for (index, list) in reordered.enumerated() {
            list.sortIndex = index
            list.updatedAt = Date()
        }
        try? modelContext.save()
    }

    private func normalizeListOrder() {
        for (index, list) in lists.sorted(by: { $0.sortIndex < $1.sortIndex }).enumerated() {
            list.sortIndex = index
        }
    }

    private func isFirstList(_ list: TaskList) -> Bool {
        lists.first?.id == list.id
    }

    private func isLastList(_ list: TaskList) -> Bool {
        lists.last?.id == list.id
    }
}
