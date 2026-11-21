//
//  LockScreenTitlePrompt.swift
//  Cadence
//

import SwiftData
import SwiftUI

struct LockScreenTitlePrompt: View {
    let scope: LockScreenScope

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var titleFocused: Bool
    @State private var title = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField(
                    "",
                    text: $title,
                    prompt: Text("Task title").foregroundStyle(Theme.textTertiary)
                )
                .focused($titleFocused)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .submitLabel(.done)
                .onSubmit(add)
                .padding(18)
                .background(Theme.surface, in: .rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.strokeSoft, lineWidth: 1)
                )
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.background)
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .onAppear {
            UserDefaults(suiteName: CadenceAppGroup.identifier)?
                .removeObject(forKey: CadenceAppGroup.fallbackScopeKey)
            titleFocused = true
        }
    }

    private func add() {
        let saved: Bool
        do {
            saved = try saveLockScreenTask(title: title, scope: scope, now: Date(), context: modelContext)
        } catch {
            return
        }
        guard saved else { return }

        let tasks: [CadenceTask]
        let lists: [TaskList]
        do {
            tasks = try modelContext.fetch(FetchDescriptor<CadenceTask>())
            lists = try modelContext.fetch(FetchDescriptor<TaskList>())
        } catch {
            dismiss()
            return
        }

        dismiss()
        Task {
            do {
                try await updateLockScreenAfterAdd(scope: scope, tasks: tasks, lists: lists)
            } catch {
                return
            }
        }
    }
}
