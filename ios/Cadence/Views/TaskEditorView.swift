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

    @FocusState private var titleFocused: Bool
    @State private var title: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var priority: TaskPriority
    @State private var selectedListId: UUID?

    private var isNewTask: Bool { task == nil }

    init(task: CadenceTask?, preferredListId: UUID?, preferredDueDate: Date? = nil) {
        self.task = task
        self.preferredListId = preferredListId
        self.preferredDueDate = preferredDueDate
        _title = State(initialValue: task?.title ?? "")
        _hasDueDate = State(initialValue: task?.dueDate != nil || preferredDueDate != nil)
        _dueDate = State(initialValue: task?.dueDate ?? preferredDueDate ?? Date())
        _priority = State(initialValue: task?.priority ?? .none)
        _selectedListId = State(initialValue: task?.listId ?? preferredListId)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isNewTask {
                    newTaskForm
                } else {
                    editTaskForm
                }
            }
            .background(Theme.background)
            .navigationTitle(isNewTask ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isNewTask ? "Add" : "Save") {
                        save()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(canSave ? Theme.accent : Theme.textTertiary)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if selectedListId == nil {
                    selectedListId = preferredListId ?? lists.first?.id
                }
                titleFocused = true
            }
        }
    }

    private var newTaskForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            titleField
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var editTaskForm: some View {
        ScrollView {
            VStack(spacing: 16) {
                titleField
                scheduleCard
                listCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var titleField: some View {
        TextField("", text: $title, prompt: Text("Task title").foregroundStyle(Theme.textTertiary))
            .focused($titleFocused)
            .font(.system(size: 21, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.textPrimary)
            .submitLabel(.done)
            .onSubmit {
                if canSave { save() }
            }
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

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        if let task {
            task.title = trimmedTitle
            task.dueDate = hasDueDate ? Calendar.current.startOfDay(for: dueDate) : nil
            task.priority = priority
            task.listId = selectedListId
            task.updatedAt = Date()
        } else {
            modelContext.insert(
                CadenceTask(
                    title: trimmedTitle,
                    dueDate: preferredDueDate.map { Calendar.current.startOfDay(for: $0) },
                    listId: preferredListId ?? selectedListId
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
