//
//  MainTabView.swift
//  Cadence
//

import SwiftUI

/// Shared top-level navigation for the authorized app experience.
struct MainTabView: View {
    let store: CalendarStore
    let notifications: NotificationManager

    @State private var selection = Tab.calendar

    private enum Tab {
        case calendar, planner, tasks
    }

    var body: some View {
        TabView(selection: $selection) {
            CalendarHomeView(store: store, notifications: notifications)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(Tab.calendar)

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
    }
}
