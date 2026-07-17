//
//  TaskDetailView.swift
//  Cadence
//

import SwiftData
import SwiftUI

struct TaskDetailView: View {
    let task: CadenceTask

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskList.sortIndex) private var lists: [TaskList]

    @State private var showEditor = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    detailsCard
                    actionStack
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Edit") { showEditor = true }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .sheet(isPresented: $showEditor) {
                TaskEditorView(task: task, preferredListId: task.listId)
                    .presentationDetents([.medium, .large])
            }
            .confirmationDialog("Delete Task?", isPresented: $showDeleteConfirmation) {
                Button("Delete Task", role: .destructive) {
                    deleteTask()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes “\(task.title)” immediately.")
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: toggleCompletion) {
                    Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(task.completed ? Theme.coolAccent : Theme.textTertiary)
                        .symbolEffect(.bounce, value: task.completed)
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.86))
                .accessibilityLabel(task.completed ? "Mark task incomplete" : "Mark task complete")

                VStack(alignment: .leading, spacing: 5) {
                    Text(task.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .strikethrough(task.completed, color: Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(task.completed ? "Completed" : "Open")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(task.completed ? Theme.coolAccent : Theme.accent)
                }
            }

            if !task.notes.isEmpty {
                Text(task.notes)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceGradient, in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.strokeSoft, lineWidth: 1)
        )
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailRow(icon: "calendar", title: "Due Date", value: dueDateLabel)
            detailRow(icon: task.priority.symbolName, title: "Priority", value: task.priority.label)
            detailRow(icon: "list.bullet.rectangle", title: "List", value: listName)
            detailRow(icon: "clock", title: "Updated", value: updatedLabel)
        }
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.strokeSoft, lineWidth: 1)
        )
    }

    private var actionStack: some View {
        VStack(spacing: 10) {
            Button(action: toggleCompletion) {
                Label(task.completed ? "Mark Incomplete" : "Mark Complete", systemImage: task.completed ? "circle" : "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(task.completed ? Theme.textSecondary : Theme.coolAccent)

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Task", systemImage: "trash")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .textCase(.uppercase)
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var dueDateLabel: String {
        guard let dueDate = task.dueDate else { return "No due date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: dueDate)
    }

    private var listName: String {
        guard let listId = task.listId else { return "No List" }
        return lists.first { $0.id == listId }?.name ?? "No List"
    }

    private var updatedLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: task.updatedAt, relativeTo: Date())
    }

    private func toggleCompletion() {
        task.completed.toggle()
        task.updatedAt = Date()
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(task.completed ? .success : .warning)
    }

    private func deleteTask() {
        modelContext.delete(task)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
