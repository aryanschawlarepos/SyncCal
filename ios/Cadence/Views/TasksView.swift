//
//  TasksView.swift
//  Cadence
//

import SwiftData
import SwiftUI

enum TaskSmartList: String, CaseIterable, Identifiable, Hashable {
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

enum TaskListScope: Equatable, Hashable {
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

    @State private var showQuickAdd = false
    @State private var quickAddTitle = ""
    @State private var showNewListPrompt = false
    @State private var newListName = ""
    @State private var showRenamePrompt = false
    @State private var renameListName = ""
    @State private var listToRename: TaskList?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                // Dashboard is a separate view so FAB / prompt state
                // does not rebuild every list card on each tap.
                TasksDashboard(
                    onCreateList: presentNewList,
                    onRenameList: beginRename
                )

                addButton
                    .zIndex(1)

                if showQuickAdd {
                    QuickTaskComposer(
                        isPresented: $showQuickAdd,
                        title: $quickAddTitle,
                        onAdd: addQuickTask
                    )
                    .zIndex(2)
                }

                if showNewListPrompt {
                    TextPromptComposer(
                        title: "New List",
                        placeholder: "List name",
                        confirmTitle: "Create",
                        isPresented: $showNewListPrompt,
                        text: $newListName,
                        onConfirm: createList
                    )
                    .zIndex(2)
                }

                if showRenamePrompt {
                    TextPromptComposer(
                        title: "Rename List",
                        placeholder: "List name",
                        confirmTitle: "Save",
                        isPresented: $showRenamePrompt,
                        text: $renameListName,
                        onConfirm: renameList
                    )
                    .zIndex(2)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: TaskListScope.self) { scope in
                TaskListDetailView(scope: scope)
            }
            .onChange(of: showRenamePrompt) { _, isPresented in
                if !isPresented {
                    listToRename = nil
                }
            }
        }
    }

    private var addButton: some View {
        Button(action: presentQuickAdd) {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 62, height: 62)
                .background(Theme.accentGradient, in: .circle)
                .shadow(color: Theme.accent.opacity(0.45), radius: 18, y: 8)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add task")
        .padding(.trailing, 22)
        .padding(.bottom, 28)
    }

    private func presentQuickAdd() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            quickAddTitle = ""
            showQuickAdd = true
        }
    }

    private func presentNewList() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            newListName = ""
            showNewListPrompt = true
        }
    }

    private func beginRename(_ list: TaskList) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            listToRename = list
            renameListName = list.name
            showRenamePrompt = true
        }
    }

    private func addQuickTask() {
        let title = quickAddTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        modelContext.insert(CadenceTask(title: title, listId: lists.first?.id))
        try? modelContext.save()
    }

    private func createList() {
        let trimmed = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(TaskList(name: trimmed, sortIndex: lists.count))
        try? modelContext.save()
        newListName = ""
    }

    private func renameList() {
        guard let listToRename else { return }
        let trimmed = renameListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        listToRename.name = trimmed
        listToRename.updatedAt = Date()
        try? modelContext.save()
        self.listToRename = nil
        renameListName = ""
    }
}

/// Isolated so prompt / FAB state in `TasksView` does not redraw every card.
private struct TasksDashboard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskList.sortIndex) private var lists: [TaskList]
    @Query(sort: \CadenceTask.createdAt, order: .reverse) private var tasks: [CadenceTask]

    @AppStorage("lockScreenAppearance", store: UserDefaults(suiteName: CadenceAppGroup.identifier)!)
    private var lockScreenAppearance = LockScreenAppearance.dark

    var onCreateList: () -> Void
    var onRenameList: (TaskList) -> Void

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var summary: TaskDashboardSummary {
        TaskDashboardSummary(tasks: tasks, today: today)
    }

    var body: some View {
        let dashboardSummary = summary

        ZStack {
            Theme.background.ignoresSafeArea()
            Theme.glow.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header(summary: dashboardSummary)
                    lockScreenAppearancePicker
                    smartLists(summary: dashboardSummary)
                    customLists(summary: dashboardSummary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 112)
            }
        }
        .task {
            await Task.yield()
            TaskSeedService.seedDefaultListsIfNeeded(in: modelContext)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lockScreenAppearancePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lock Screen")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textTertiary)

            Picker("Appearance", selection: $lockScreenAppearance) {
                Text("Light").tag(LockScreenAppearance.light)
                Text("Dark").tag(LockScreenAppearance.dark)
                Text("Transparent").tag(LockScreenAppearance.transparent)
            }
            .pickerStyle(.menu)
            .tint(Theme.textPrimary)
        }
    }

    private func smartLists(summary: TaskDashboardSummary) -> some View {
        // Only four tiles — avoid LazyVGrid hit-testing quirks inside ScrollView.
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                smartLink(.myDay, count: summary.smartCounts[.myDay, default: 0])
                smartLink(.upcoming, count: summary.smartCounts[.upcoming, default: 0])
            }
            GridRow {
                smartLink(.all, count: summary.smartCounts[.all, default: 0])
                smartLink(.completed, count: summary.smartCounts[.completed, default: 0])
            }
        }
    }

    private func smartLink(_ smartList: TaskSmartList, count: Int) -> some View {
        NavigationLink(value: TaskListScope.smart(smartList)) {
            smartListCard(smartList, count: count)
        }
        .buttonStyle(.plain)
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
            }

            Text(smartList.title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.surfaceGradient, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.strokeSoft, lineWidth: 1)
        )
        .contentShape(.rect(cornerRadius: 18))
    }

    private func customLists(summary: TaskDashboardSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Lists")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .textCase(.uppercase)

                Spacer()

                Button(action: onCreateList) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 30, height: 30)
                        .background(Theme.accentSoft, in: .circle)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create list")
            }

            if lists.isEmpty {
                emptyLists
            } else {
                VStack(spacing: 8) {
                    ForEach(lists) { list in
                        NavigationLink(value: TaskListScope.custom(list.id, list.name)) {
                            customListRow(list, count: summary.openCountsByListId[list.id, default: 0])
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                onRenameList(list)
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
        .contentShape(.rect(cornerRadius: 16))
    }

    private var emptyLists: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.accent)

            Text("Create your first list.")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            Button("New List", action: onCreateList)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.accentGradient, in: .capsule)
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(Theme.surface, in: .rect(cornerRadius: 18))
    }

    private func color(for smartList: TaskSmartList) -> Color {
        switch smartList {
        case .myDay: return Theme.accent
        case .upcoming: return Theme.coolAccent
        case .all: return Color(hex: 0xB6A7FF)
        case .completed: return Color(hex: 0x7BD88F)
        }
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

        var reordered = Array(lists)
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
