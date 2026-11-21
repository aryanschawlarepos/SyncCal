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
) async throws {
    let appearance = storedLockScreenAppearance()
    var pinError: LockScreenPinError?
    if !ListLiveActivityCenter.isRunning(scope) {
        let names = Dictionary(lists.map { ($0.id, $0.name) }, uniquingKeysWith: { _, latest in latest })
        if let name = lockScreenDisplayName(scope: scope, listNames: names) {
            do {
                try await ListLiveActivityCenter.pin(
                    scope: scope,
                    name: name,
                    tasks: tasks,
                    appearance: appearance
                )
            } catch let error as LockScreenPinError {
                pinError = error
            }
        }
    }
    await ListLiveActivityCenter.sync(tasks: tasks, lists: lists, appearance: appearance)
    if let pinError {
        throw pinError
    }
}

struct AddLockScreenTaskIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var openAppWhenRun = false

    @Parameter(title: "Title")
    var title: String?

    // Success returns `.result()` and does not open a URL. A missing group store
    // or a failed title request returns `.result(opensIntent:)`. `any IntentResult`
    // is what lets those containers share one `perform()`. If `AppIntent.PerformResult`
    // refuses the existential, this will not compile: the two result containers are
    // different types, and `some IntentResult` cannot mix them.
    func perform() async throws -> any IntentResult {
        let scope = await currentLockScreenAddScope()
        let provided: String
        do {
            let value = try await $title.requestValue(IntentDialog("Task title"))
            provided = value ?? ""
        } catch is CancellationError {
            return .result() as any IntentResult
        } catch {
            storeLockScreenFallbackScope(scope)
            return .result(opensIntent: OpenURLIntent(CadenceAppGroup.addURL)) as any IntentResult
        }

        do {
            _ = try await saveLockScreenAdd(title: provided, scope: scope)
        } catch is LockScreenPinError {
            return .result() as any IntentResult
        } catch let error as CadenceStoreError {
            guard case .groupStoreMissing = error else {
                return .result() as any IntentResult
            }
            storeLockScreenFallbackScope(scope)
            if let title = normalizedLockScreenTitle(provided) {
                storeLockScreenStashedTitle(title)
            }
            return .result(opensIntent: OpenURLIntent(CadenceAppGroup.addURL)) as any IntentResult
        }
        return .result() as any IntentResult
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
        do {
            try await writeLockScreenCompletion(id: id)
        } catch is CadenceStoreError {
            return .result()
        }
        return .result()
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

private func storeLockScreenStashedTitle(_ title: String) {
    let defaults = UserDefaults(suiteName: CadenceAppGroup.identifier)
    defaults?.set(title, forKey: CadenceAppGroup.stashedTitleKey)
    defaults?.synchronize()
}

struct PendingLockScreenAdd: Equatable {
    var scope: LockScreenScope
    var title: String?
}

func takePendingLockScreenAdd() -> PendingLockScreenAdd? {
    guard let defaults = UserDefaults(suiteName: CadenceAppGroup.identifier),
          let raw = defaults.string(forKey: CadenceAppGroup.fallbackScopeKey) else {
        return nil
    }
    let title = defaults.string(forKey: CadenceAppGroup.stashedTitleKey)
    defaults.removeObject(forKey: CadenceAppGroup.fallbackScopeKey)
    defaults.removeObject(forKey: CadenceAppGroup.stashedTitleKey)
    defaults.synchronize()
    return PendingLockScreenAdd(
        scope: LockScreenScope.scope(id: raw) ?? .myDay,
        title: title
    )
}

@MainActor
func finishStashedLockScreenAdd(title: String, scope: LockScreenScope) async -> Bool {
    do {
        let context = try CadenceSharedContainer.context()
        let saved = try saveLockScreenTask(title: title, scope: scope, now: Date(), context: context)
        guard saved else { return false }
        let tasks = try context.fetch(FetchDescriptor<CadenceTask>())
        let lists = try context.fetch(FetchDescriptor<TaskList>())
        try await updateLockScreenAfterAdd(scope: scope, tasks: tasks, lists: lists)
        return true
    } catch is LockScreenPinError {
        return true
    } catch {
        return false
    }
}

func storedLockScreenAppearance() -> LockScreenAppearance {
    let raw = UserDefaults(suiteName: CadenceAppGroup.identifier)?.string(forKey: "lockScreenAppearance")
    return raw.flatMap(LockScreenAppearance.init(rawValue:)) ?? .standard
}

@MainActor
private func saveLockScreenAdd(title: String, scope: LockScreenScope) async throws -> Bool {
    let context = try CadenceSharedContainer.context()
    let saved = try saveLockScreenTask(title: title, scope: scope, now: Date(), context: context)
    guard saved else { return false }
    let tasks = try context.fetch(FetchDescriptor<CadenceTask>())
    let lists = try context.fetch(FetchDescriptor<TaskList>())
    try await updateLockScreenAfterAdd(scope: scope, tasks: tasks, lists: lists)
    return true
}

@MainActor
private func writeLockScreenCompletion(id: UUID) async throws {
    let context = try CadenceSharedContainer.context()
    _ = try completeLockScreenTask(id: id, context: context)
    let tasks = try context.fetch(FetchDescriptor<CadenceTask>())
    let lists = try context.fetch(FetchDescriptor<TaskList>())
    await ListLiveActivityCenter.sync(
        tasks: tasks,
        lists: lists,
        appearance: storedLockScreenAppearance()
    )
}
