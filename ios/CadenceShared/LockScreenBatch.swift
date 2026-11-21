//
//  LockScreenBatch.swift
//  Cadence
//

import ActivityKit
import Foundation

private let lockScreenBatchLimit = 3

enum LockScreenScope: Hashable, Codable, Equatable {
    case myDay
    case list(UUID)

    var id: String {
        switch self {
        case .myDay:
            return "myDay"
        case .list(let listID):
            return listID.uuidString
        }
    }

    static func scope(id: String) -> LockScreenScope? {
        if id == "myDay" {
            return .myDay
        }
        guard let listID = UUID(uuidString: id) else {
            return nil
        }
        return .list(listID)
    }
}

enum LockScreenAppearance: String, Codable, Hashable, CaseIterable {
    case light
    case dark
    case transparent
}

struct LockScreenSourceTask: Equatable {
    var id: UUID
    var title: String
    var completed: Bool
    var dueDate: Date?
    var listId: UUID?
    var createdAt: Date
}

struct LockScreenTaskRow: Hashable, Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var completed: Bool
}

enum LockScreenCardState: Equatable {
    case ended
    case showing(rows: [LockScreenTaskRow], openCount: Int)
}

func resolveLockScreenCard(
    scope: LockScreenScope,
    tasks: [LockScreenSourceTask],
    currentIDs: [UUID],
    today: Date,
    calendar: Calendar
) -> LockScreenCardState {
    let inScope = tasks.filter { task in scope.contains(task, today: today, calendar: calendar) }
    let openCount = inScope.filter { !$0.completed }.count
    let tasksByID = Dictionary(inScope.map { ($0.id, $0) }, uniquingKeysWith: { current, _ in current })
    let remaining = currentIDs.compactMap { tasksByID[$0] }

    if remaining.contains(where: { !$0.completed }) {
        return .showing(rows: remaining.map(lockScreenRow), openCount: openCount)
    }

    if !remaining.isEmpty && openCount == 0 {
        return .showing(rows: remaining.map(lockScreenRow), openCount: openCount)
    }

    let nextBatch = inScope
        .filter { !$0.completed }
        .sorted(by: lockScreenNextBatchPrecedes)
        .prefix(lockScreenBatchLimit)
        .map(lockScreenRow)

    guard !nextBatch.isEmpty else {
        return .ended
    }
    return .showing(rows: nextBatch, openCount: openCount)
}

enum LockScreenActivityCommand: Equatable {
    case skip
    case start
    case update
    case end
}

func lockScreenActivityCommand(state: LockScreenCardState, isRunning: Bool) -> LockScreenActivityCommand {
    switch state {
    case .ended:
        return isRunning ? .end : .skip
    case .showing:
        return isRunning ? .update : .start
    }
}

func lockScreenAddDestination(running: [(scope: LockScreenScope, pinnedAt: Date)]) -> LockScreenScope {
    running.max { lhs, rhs in
        if lhs.pinnedAt == rhs.pinnedAt {
            return rhs.scope.id > lhs.scope.id
        }
        return lhs.pinnedAt < rhs.pinnedAt
    }?.scope ?? .myDay
}

func normalizedLockScreenTitle(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

func lockScreenWriteCompletion(isCompleted: Bool) -> Bool? {
    isCompleted ? nil : true
}

enum LockScreenPinError: Error, Equatable {
    case empty
    case disabled
    case system(String)
}

func lockScreenPinError(activitiesEnabled: Bool, state: LockScreenCardState) -> LockScreenPinError? {
    if !activitiesEnabled {
        return .disabled
    }
    if case .ended = state {
        return .empty
    }
    return nil
}

struct ListActivityAttributes: ActivityAttributes {
    var scopeID: String
    var pinnedAt: Date

    struct ContentState: Codable, Hashable {
        var name: String
        var openCount: Int
        var rows: [LockScreenTaskRow]
        var appearance: LockScreenAppearance
    }
}

func lockScreenContent(
    name: String,
    state: LockScreenCardState,
    appearance: LockScreenAppearance
) -> ListActivityAttributes.ContentState? {
    guard case .showing(let rows, let openCount) = state else {
        return nil
    }
    return ListActivityAttributes.ContentState(
        name: name,
        openCount: openCount,
        rows: rows,
        appearance: appearance
    )
}

func lockScreenDisplayName(scope: LockScreenScope, listNames: [UUID: String]) -> String? {
    switch scope {
    case .myDay:
        return "My Day"
    case .list(let listID):
        return listNames[listID]
    }
}

private extension LockScreenScope {
    func contains(_ task: LockScreenSourceTask, today: Date, calendar: Calendar) -> Bool {
        switch self {
        case .myDay:
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: today)
        case .list(let listID):
            return task.listId == listID
        }
    }
}

private func lockScreenNextBatchPrecedes(_ lhs: LockScreenSourceTask, _ rhs: LockScreenSourceTask) -> Bool {
    switch (lhs.dueDate, rhs.dueDate) {
    case let (left?, right?) where left != right:
        return left < right
    case (.some, nil):
        return true
    case (nil, .some):
        return false
    default:
        return lhs.createdAt > rhs.createdAt
    }
}

private func lockScreenRow(_ task: LockScreenSourceTask) -> LockScreenTaskRow {
    LockScreenTaskRow(id: task.id, title: task.title, completed: task.completed)
}
