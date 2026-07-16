//
//  ContentView.swift
//  Cadence
//

import SwiftUI

/// Root view: routes between the onboarding permission gate and the calendar home.
struct ContentView: View {
    @State private var notifications = NotificationManager()
    @State private var store: CalendarStore

    init() {
        let notifications = NotificationManager()
        _notifications = State(initialValue: notifications)
        _store = State(initialValue: CalendarStore(notifications: notifications))
    }

    var body: some View {
        Group {
            if store.hasAccess {
                CalendarHomeView(store: store, notifications: notifications)
                    .transition(.opacity)
            } else {
                PermissionGateView(store: store)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: store.hasAccess)
        .preferredColorScheme(.dark)
        .task {
            await notifications.refreshStatus()
            if store.hasAccess {
                store.loadCalendars()
                store.reload()
            }
        }
    }
}

#Preview {
    ContentView()
}
