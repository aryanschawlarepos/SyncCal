//
//  MainTabView.swift
//  Cadence
//

import SwiftData
import SwiftUI

/// Shared top-level navigation for the authorized app experience.
struct MainTabView: View {
    let store: CalendarStore
    let notifications: NotificationManager

    @Query(sort: \CadenceTask.createdAt, order: .reverse) private var tasks: [CadenceTask]
    @Query(sort: \TaskList.sortIndex) private var lists: [TaskList]
    @AppStorage("lockScreenAppearance", store: UserDefaults(suiteName: CadenceAppGroup.identifier)!)
    private var lockScreenAppearance = LockScreenAppearance.dark

    @State private var selection = Tab.calendar

    private enum Tab {
        case calendar, upcoming, planner, tasks
    }

    var body: some View {
        TabView(selection: $selection) {
            CalendarHomeView(store: store, notifications: notifications)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(Tab.calendar)

            UpcomingView(store: store, notifications: notifications)
                .tabItem {
                    Label("Upcoming", systemImage: "calendar.badge.clock")
                }
                .tag(Tab.upcoming)

            PlannerView(store: store, notifications: notifications)
                .tabItem {
                    Label("Planner", systemImage: "list.bullet.rectangle")
                }
                .tag(Tab.planner)

            TasksView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
                .tag(Tab.tasks)
        }
        .tint(Theme.accent)
        .task(id: lockScreenSyncToken) {
            // Debounce so launch seeding and rapid edits don't stall the UI
            // on ActivityKit updates for every intermediate @Query change.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await ListLiveActivityCenter.sync(
                tasks: Array(tasks),
                lists: Array(lists),
                appearance: lockScreenAppearance
            )
        }
    }

    /// Change token for Live Activity sync — cheaper than a giant joined string.
    private var lockScreenSyncToken: Int {
        var hasher = Hasher()
        hasher.combine(lockScreenAppearance)
        hasher.combine(tasks.count)
        hasher.combine(lists.count)
        for task in tasks {
            hasher.combine(task.id)
            hasher.combine(task.title)
            hasher.combine(task.completed)
            hasher.combine(task.updatedAt.timeIntervalSince1970)
            hasher.combine(task.dueDate?.timeIntervalSince1970)
            hasher.combine(task.listId)
        }
        for list in lists {
            hasher.combine(list.id)
            hasher.combine(list.name)
        }
        return hasher.finalize()
    }
}
