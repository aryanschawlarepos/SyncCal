//
//  LockScreenIntents.swift
//  Cadence
//

import ActivityKit
import AppIntents
import Foundation
import SwiftData

@MainActor
func saveLockScreenTask(
    title: String,
    scope: LockScreenScope,
    now: Date,
    context: ModelContext
) throws -> Bool {
    guard let title = normalizedLockScreenTitle(title) else {
        return false
    }

    let dueDate: Date?
    let listId: UUID?
    switch scope {
    case .myDay:
        dueDate = now
        listId = nil
    case .list(let listID):
        dueDate = nil
        listId = listID
    }

    let task = CadenceTask(
        title: title,
        dueDate: dueDate,
        completed: false,
        createdAt: now,
        updatedAt: now,
        listId: listId
    )
    context.insert(task)
    try context.save()
    return true
}

@MainActor
func completeLockScreenTask(id: UUID, context: ModelContext) throws -> Bool {
    let identifier = id
    var descriptor = FetchDescriptor<CadenceTask>(
        predicate: #Predicate<CadenceTask> { task in
            task.id == identifier
        }
    )
    descriptor.fetchLimit = 1
    guard let task = try context.fetch(descriptor).first else {
        return false
    }
    guard let completed = lockScreenWriteCompletion(isCompleted: task.completed) else {
        return false
    }
    task.completed = completed
    task.updatedAt = Date()
    try context.save()
    return true
}

@MainActor
func updateLockScreenAfterAdd(
    scope: LockScreenScope,
    tasks: [CadenceTask],
    lists: [TaskList]
) async {
    let appearance = storedLockScreenAppearance()
    if !ListLiveActivityCenter.isRunning(scope) {
        let names = Dictionary(lists.map { ($0.id, $0.name) }, uniquingKeysWith: { _, latest in latest })
        if let name = lockScreenDisplayName(scope: scope, listNames: names) {
            try? await ListLiveActivityCenter.pin(
                scope: scope,
                name: name,
                tasks: tasks,
                appearance: appearance
            )
        }
    }
    await ListLiveActivityCenter.sync(tasks: tasks, lists: lists, appearance: appearance)
}

struct AddLockScreenTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var openAppWhenRun = false

    @Parameter(title: "Title")
    var title: String?

    func perform() async throws -> some IntentResult {
        let scope = await currentLockScreenAddScope()
        let provided: String
        do {
            let value = try await $title.requestValue(IntentDialog("Task title"))
            provided = value ?? ""
        } catch {
            storeLockScreenFallbackScope(scope)
            return .result(opensIntent: OpenURLIntent(target: CadenceAppGroup.addURL))
        }

        _ = try await saveLockScreenAdd(title: provided, scope: scope)
        return .result()
    }
}

struct CompleteLockScreenTaskIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Task"
    static var openAppWhenRun = false

    @Parameter(title: "Task")
    var taskID: String

    init() {
        taskID = ""
    }

    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: taskID) else {
            return .result()
        }
        try await writeLockScreenCompletion(id: id)
        return .result()
    }
}

struct OpenLockScreenAddIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var openAppWhenRun = true
    static var isDiscoverable: Bool { false }

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(CadenceAppGroup.addURL))
    }
}

@MainActor
private func currentLockScreenAddScope() -> LockScreenScope {
    let running: [(scope: LockScreenScope, pinnedAt: Date)] = Activity<ListActivityAttributes>.activities.compactMap { activity in
        guard let scope = LockScreenScope.scope(id: activity.attributes.scopeID) else {
            return nil
        }
        return (scope: scope, pinnedAt: activity.attributes.pinnedAt)
    }
    return lockScreenAddDestination(running: running)
}

private func storeLockScreenFallbackScope(_ scope: LockScreenScope) {
    let defaults = UserDefaults(suiteName: CadenceAppGroup.identifier)
    defaults?.set(scope.id, forKey: CadenceAppGroup.fallbackScopeKey)
    defaults?.synchronize()
}

private func storedLockScreenAppearance() -> LockScreenAppearance {
    let raw = UserDefaults(suiteName: CadenceAppGroup.identifier)?.string(forKey: "lockScreenAppearance")
    return raw.flatMap(LockScreenAppearance.init(rawValue:)) ?? .standard
}

@MainActor
private func saveLockScreenAdd(title: String, scope: LockScreenScope) async throws -> Bool {
    let container = try makeCadenceContainer()
    let context = container.mainContext
    let saved = try saveLockScreenTask(title: title, scope: scope, now: Date(), context: context)
    guard saved else { return false }
    let tasks = try context.fetch(FetchDescriptor<CadenceTask>())
    let lists = try context.fetch(FetchDescriptor<TaskList>())
    await updateLockScreenAfterAdd(scope: scope, tasks: tasks, lists: lists)
    return true
}

@MainActor
private func writeLockScreenCompletion(id: UUID) async throws {
    let container = try makeCadenceContainer()
    let context = container.mainContext
    _ = try completeLockScreenTask(id: id, context: context)
    let tasks = try context.fetch(FetchDescriptor<CadenceTask>())
    let lists = try context.fetch(FetchDescriptor<TaskList>())
    await ListLiveActivityCenter.sync(
        tasks: tasks,
        lists: lists,
        appearance: storedLockScreenAppearance()
    )
}
