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
        .background(LockScreenActivitySyncBridge())
    }
}

/// Keeps Live Activity sync off the tab bar’s render path. Debounced updates
/// run in this tiny host so opening menus and the + button stay instant.
private struct LockScreenActivitySyncBridge: View {
    @Query(sort: \CadenceTask.updatedAt, order: .reverse) private var tasks: [CadenceTask]
    @Query(sort: \TaskList.sortIndex) private var lists: [TaskList]
    @AppStorage("lockScreenAppearance", store: UserDefaults(suiteName: CadenceAppGroup.identifier)!)
    private var lockScreenAppearance = LockScreenAppearance.dark

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .task(id: syncToken) {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await ListLiveActivityCenter.sync(
                    tasks: Array(tasks),
                    lists: Array(lists),
                    appearance: lockScreenAppearance
                )
            }
    }

    private var syncToken: String {
        let newest = tasks.first.map {
            "\($0.id.uuidString):\($0.updatedAt.timeIntervalSince1970):\($0.title):\($0.completed)"
        } ?? "none"
        let completedCount = tasks.reduce(into: 0) { count, task in
            if task.completed { count += 1 }
        }
        let listStamp = lists.map { "\($0.id.uuidString):\($0.name)" }.joined(separator: ",")
        return "\(tasks.count)|\(completedCount)|\(newest)|\(listStamp)|\(lockScreenAppearance.rawValue)"
    }
}
