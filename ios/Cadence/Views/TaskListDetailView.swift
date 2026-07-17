//
//  TaskListDetailView.swift
//  Cadence
//

import SwiftData
import SwiftUI

struct TaskListDetailView: View {
    let scope: TaskListScope

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \CadenceTask.createdAt, order: .reverse) private var tasks: [CadenceTask]
    @Query(sort: \TaskList.sortIndex) private var lists: [TaskList]

    @State private var quickAddTitle = ""
    @State private var taskToEdit: CadenceTask?
    @State private var taskToDirectEdit: CadenceTask?
    @State private var taskPendingDelete: CadenceTask?
    @State private var showEditor = false

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var snapshot: TaskListSnapshot {
        TaskListSnapshot(scope: scope, tasks: tasks, today: today)
    }

    var body: some View {
        let listSnapshot = snapshot

        ZStack(alignment: .bottomTrailing) {
            Theme.background.ignoresSafeArea()
            Theme.glow.ignoresSafeArea()

            VStack(spacing: 0) {
                header(snapshot: listSnapshot)

                quickAddBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)

                content(snapshot: listSnapshot)
            }

            addButton
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .sheet(isPresented: $showEditor) {
            TaskEditorView(task: nil, preferredListId: preferredListId)
        }
        .sheet(item: $taskToEdit) { task in
            TaskDetailView(task: task)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $taskToDirectEdit) { task in
            TaskEditorView(task: task, preferredListId: task.listId ?? preferredListId)
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Delete Task?", isPresented: taskDeleteDialogBinding) {
            if let taskPendingDelete {
                Button("Delete Task", role: .destructive) {
                    delete(taskPendingDelete)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let taskPendingDelete {
                Text("This removes “\(taskPendingDelete.title)” immediately.")
            }
        }
    }

    private func header(snapshot: TaskListSnapshot) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: scope.symbolName)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 46, height: 46)
                .background(Theme.accentSoft, in: .circle)

            VStack(alignment: .leading, spacing: 3) {
                Text(scope.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("\(snapshot.tasks.count) \(snapshot.tasks.count == 1 ? "task" : "tasks")")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .contentTransition(.numericText())
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var quickAddBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.accent)

            TextField("Add a task", text: $quickAddTitle)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .submitLabel(.done)
                .onSubmit(createQuickTask)

            Button(action: createQuickTask) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(canQuickAdd ? Theme.accent : Theme.textTertiary)
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.9))
            .disabled(!canQuickAdd)
            .accessibilityLabel("Add task")
        }
        .padding(14)
        .background(Theme.surface, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.strokeSoft, lineWidth: 1)
        )
    }

    private func content(snapshot: TaskListSnapshot) -> some View {
        Group {
            if snapshot.tasks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(snapshot.tasks) { task in
                            TaskRow(task: task) {
                                taskToEdit = task
                            } onEdit: {
                                taskToDirectEdit = task
                            } onToggle: {
                                toggle(task)
                            } onDelete: {
                                taskPendingDelete = task
                            }
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 112)
                }
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.16) : .spring(response: 0.28, dampingFraction: 0.9), value: snapshot.tasks.map(\.id))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.coolAccent.opacity(0.14))
                    .frame(width: 84, height: 84)

                Image(systemName: emptySymbolName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.coolAccent)
            }

            Text(emptyTitle)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            Text(emptyMessage)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 280)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showEditor = true
            } label: {
                Label("Add Task", systemImage: "plus")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Theme.accentGradient, in: .capsule)
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.94))
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }

    private var addButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showEditor = true
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

    private var canQuickAdd: Bool {
        !quickAddTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var preferredListId: UUID? {
        switch scope {
        case .custom(let listId, _):
            return listId
        case .smart:
            return lists.first?.id
        }
    }

    private var emptyTitle: String {
        switch scope {
        case .smart(let smartList): return smartList.emptyTitle
        case .custom: return "You're all caught up."
        }
    }

    private var emptyMessage: String {
        switch scope {
        case .smart(let smartList): return smartList.emptyMessage
        case .custom: return "Add a task to this list when something needs attention."
        }
    }

    private var emptySymbolName: String {
        switch scope {
        case .smart(.completed): return "checkmark.seal"
        case .smart(.upcoming): return "calendar"
        default: return "sparkles"
        }
    }

    private func createQuickTask() {
        let title = quickAddTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let task = CadenceTask(
            title: title,
            dueDate: defaultDueDate,
            listId: preferredListId
        )
        modelContext.insert(task)
        try? modelContext.save()
        quickAddTitle = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private var defaultDueDate: Date? {
        switch scope {
        case .smart(.myDay):
            return Date()
        default:
            return nil
        }
    }

    private func toggle(_ task: CadenceTask) {
        task.completed.toggle()
        task.updatedAt = Date()
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(task.completed ? .success : .warning)
    }

    private func delete(_ task: CadenceTask) {
        modelContext.delete(task)
        try? modelContext.save()
        taskPendingDelete = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private var taskDeleteDialogBinding: Binding<Bool> {
        Binding(
            get: { taskPendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    taskPendingDelete = nil
                }
            }
        )
    }
}
