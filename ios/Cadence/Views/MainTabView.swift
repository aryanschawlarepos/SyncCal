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
        .task(id: lockScreenSyncID) {
            await ListLiveActivityCenter.sync(
                tasks: tasks,
                lists: lists,
                appearance: lockScreenAppearance
            )
        }
    }

    private var lockScreenSyncID: String {
        let taskPart = tasks.map { task in
            [
                task.id.uuidString,
                task.title,
                task.completed ? "1" : "0",
                task.dueDate.map { String($0.timeIntervalSince1970) } ?? "",
                task.listId?.uuidString ?? "",
                String(task.createdAt.timeIntervalSince1970)
            ].joined(separator: "\u{1f}")
        }.joined(separator: "\u{1e}")
        let listPart = lists.map { list in
            [list.id.uuidString, list.name].joined(separator: "\u{1f}")
        }.joined(separator: "\u{1e}")
        return taskPart + "\u{1d}" + listPart + "\u{1d}" + lockScreenAppearance.rawValue
    }
}
