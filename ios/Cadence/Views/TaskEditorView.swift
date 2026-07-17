//
//  TaskEditorView.swift
//  Cadence
//

import SwiftData
import SwiftUI

struct TaskEditorView: View {
    let task: CadenceTask?
    let preferredListId: UUID?
    let preferredDueDate: Date?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskList.sortIndex) private var lists: [TaskList]

    @State private var title: String
    @State private var notes: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var priority: TaskPriority
    @State private var selectedListId: UUID?

    init(task: CadenceTask?, preferredListId: UUID?, preferredDueDate: Date? = nil) {
        self.task = task
        self.preferredListId = preferredListId
        self.preferredDueDate = preferredDueDate
        _title = State(initialValue: task?.title ?? "")
        _notes = State(initialValue: task?.notes ?? "")
        _hasDueDate = State(initialValue: task?.dueDate != nil || preferredDueDate != nil)
        _dueDate = State(initialValue: task?.dueDate ?? preferredDueDate ?? Date())
        _priority = State(initialValue: task?.priority ?? .none)
        _selectedListId = State(initialValue: task?.listId ?? preferredListId)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    titleCard
                    scheduleCard
                    listCard
                    notesCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
            .background(Theme.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(task == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(task == nil ? "Add" : "Save") {
                        save()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(canSave ? Theme.accent : Theme.textTertiary)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if selectedListId == nil {
                    selectedListId = lists.first?.id
                }
            }
        }
    }

    private var titleCard: some View {
        TextField("", text: $title, prompt: Text("Task title").foregroundStyle(Theme.textTertiary))
            .font(.system(size: 21, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.textPrimary)
            .padding(18)
            .background(Theme.surface, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.strokeSoft, lineWidth: 1)
            )
    }

    private var scheduleCard: some View {
        TaskEditorCard {
            Toggle(isOn: $hasDueDate.animation(.spring(response: 0.3, dampingFraction: 0.84))) {
                Label("Due Date", systemImage: "calendar")
                    .foregroundStyle(Theme.textPrimary)
            }
            .tint(Theme.accent)

            if hasDueDate {
                Divider().overlay(Theme.stroke)

                DatePicker("Due", selection: $dueDate, displayedComponents: [.date])
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.accent)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider().overlay(Theme.stroke)

            Picker(selection: $priority) {
                ForEach(TaskPriority.allCases) { priority in
                    Label(priority.label, systemImage: priority.symbolName)
                        .tag(priority)
                }
            } label: {
                Label("Priority", systemImage: "flag")
                    .foregroundStyle(Theme.textPrimary)
            }
            .pickerStyle(.menu)
            .tint(Theme.accent)
        }
    }

    private var listCard: some View {
        TaskEditorCard {
            Picker(selection: $selectedListId) {
                Text("No List").tag(UUID?.none)
                ForEach(lists) { list in
                    Text(list.name).tag(Optional(list.id))
                }
            } label: {
                Label("List", systemImage: "list.bullet.rectangle")
                    .foregroundStyle(Theme.textPrimary)
            }
            .pickerStyle(.menu)
            .tint(Theme.accent)
        }
    }

    private var notesCard: some View {
        TaskEditorCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 2)

                TextField("", text: $notes, prompt: Text("Notes").foregroundStyle(Theme.textTertiary), axis: .vertical)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(4 ... 8)
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        if let task {
            task.title = trimmedTitle
            task.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            task.dueDate = hasDueDate ? Calendar.current.startOfDay(for: dueDate) : nil
            task.priority = priority
            task.listId = selectedListId
            task.updatedAt = Date()
        } else {
            modelContext.insert(
                CadenceTask(
                    title: trimmedTitle,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    dueDate: hasDueDate ? Calendar.current.startOfDay(for: dueDate) : nil,
                    priority: priority,
                    listId: selectedListId
                )
            )
        }

        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

private struct TaskEditorCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 12) {
            content
        }
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.strokeSoft, lineWidth: 1)
        )
    }
}
