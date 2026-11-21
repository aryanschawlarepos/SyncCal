//
//  ListLiveActivityCenter.swift
//  Cadence
//

import ActivityKit
import Foundation

extension Notification.Name {
    static let cadenceLockScreenActivitiesChanged = Notification.Name("cadence.lockScreenActivities.changed")
}

@MainActor
enum ListLiveActivityCenter {
    static func isRunning(_ scope: LockScreenScope) -> Bool {
        Activity<ListActivityAttributes>.activities.contains { $0.attributes.scopeID == scope.id }
    }

    static func pin(
        scope: LockScreenScope,
        name: String,
        tasks: [CadenceTask],
        appearance: LockScreenAppearance
    ) async throws {
        let existing = activities(for: scope)
        let state = resolveLockScreenCard(
            scope: scope,
            tasks: tasks.map(lockScreenSourceTask),
            currentIDs: existing.first?.content.state.rows.map(\.id) ?? [],
            today: Date(),
            calendar: .current
        )
        if let error = lockScreenPinError(
            activitiesEnabled: ActivityAuthorizationInfo().areActivitiesEnabled,
            state: state
        ) {
            throw error
        }
        guard let content = lockScreenContent(name: name, state: state, appearance: appearance) else {
            throw LockScreenPinError.empty
        }

        let activityContent = ActivityContent(state: content, staleDate: nil)
        if !existing.isEmpty {
            for activity in existing {
                await activity.update(activityContent)
            }
            noteChange()
            return
        }

        do {
            _ = try Activity.request(
                attributes: ListActivityAttributes(scopeID: scope.id, pinnedAt: Date()),
                content: activityContent
            )
        } catch {
            throw LockScreenPinError.system(error.localizedDescription)
        }
        noteChange()
    }

    static func unpin(_ scope: LockScreenScope) async {
        let existing = activities(for: scope)
        guard !existing.isEmpty else { return }
        for activity in existing {
            await activity.end(endingContent, dismissalPolicy: .immediate)
        }
        noteChange()
    }

    static func sync(tasks: [CadenceTask], lists: [TaskList], appearance: LockScreenAppearance) async {
        let listNames = Dictionary(lists.map { ($0.id, $0.name) }, uniquingKeysWith: { _, new in new })
        let sources = tasks.map(lockScreenSourceTask)
        let today = Date()
        let calendar = Calendar.current
        var changed = false

        for activity in Activity<ListActivityAttributes>.activities {
            guard let scope = LockScreenScope.scope(id: activity.attributes.scopeID) else {
                continue
            }
            guard let name = lockScreenDisplayName(scope: scope, listNames: listNames) else {
                await activity.end(endingContent, dismissalPolicy: .immediate)
                changed = true
                continue
            }

            let currentIDs = activity.content.state.rows.map(\.id)
            let state = resolveLockScreenCard(
                scope: scope,
                tasks: sources,
                currentIDs: currentIDs,
                today: today,
                calendar: calendar
            )
            switch lockScreenActivityCommand(state: state, isRunning: true) {
            case .update:
                guard let content = lockScreenContent(name: name, state: state, appearance: appearance) else {
                    continue
                }
                await activity.update(ActivityContent(state: content, staleDate: nil))
                changed = true
            case .end:
                await activity.end(endingContent, dismissalPolicy: .immediate)
                changed = true
            case .start, .skip:
                break
            }
        }

        if changed {
            noteChange()
        }
    }

    private static func activities(for scope: LockScreenScope) -> [Activity<ListActivityAttributes>] {
        Activity<ListActivityAttributes>.activities.filter { $0.attributes.scopeID == scope.id }
    }

    private static var endingContent: ActivityContent<ListActivityAttributes.ContentState>? {
        nil
    }

    private static func noteChange() {
        NotificationCenter.default.post(name: .cadenceLockScreenActivitiesChanged, object: nil)
    }
}

private func lockScreenSourceTask(_ task: CadenceTask) -> LockScreenSourceTask {
    LockScreenSourceTask(
        id: task.id,
        title: task.title,
        completed: task.completed,
        dueDate: task.dueDate,
        listId: task.listId,
        createdAt: task.createdAt
    )
}
