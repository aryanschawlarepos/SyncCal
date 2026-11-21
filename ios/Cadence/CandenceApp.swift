//
//  CadenceApp.swift
//  Cadence
//
//  Created by Rork on July 16, 2026.
//

import SwiftData
import SwiftUI

@MainActor
final class CadenceSharedStore: ObservableObject {
    @Published private(set) var container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
        CadenceSharedContainer.container = container
    }

    func reloadAndSync() async {
        let previous = container
        previous.mainContext.autosaveEnabled = false
        previous.mainContext.rollback()
        let fresh: ModelContainer
        do {
            fresh = try makeCadenceContainer()
        } catch {
            previous.mainContext.autosaveEnabled = true
            await sync(from: previous)
            return
        }
        CadenceSharedContainer.container = fresh
        container = fresh
        await sync(from: fresh)
    }

    private func sync(from container: ModelContainer) async {
        let context = container.mainContext
        guard let tasks = try? context.fetch(FetchDescriptor<CadenceTask>()),
              let lists = try? context.fetch(FetchDescriptor<TaskList>()) else {
            return
        }
        await ListLiveActivityCenter.sync(
            tasks: tasks,
            lists: lists,
            appearance: storedLockScreenAppearance()
        )
    }
}

@main
struct CadenceApp: App {
    @StateObject private var sharedStore: CadenceSharedStore

    init() {
        if let existing = CadenceAppLaunchStore.shared {
            _sharedStore = StateObject(wrappedValue: existing)
            return
        }
        do {
            let container = try makeCadenceContainer()
            let store = CadenceSharedStore(container: container)
            CadenceAppLaunchStore.shared = store
            _sharedStore = StateObject(wrappedValue: store)
        } catch {
            fatalError("Could not open the Cadence store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(reloadSharedStore: {
                await sharedStore.reloadAndSync()
            })
            .modelContainer(sharedStore.container)
        }
    }
}

private enum CadenceAppLaunchStore {
    @MainActor static var shared: CadenceSharedStore?
}
