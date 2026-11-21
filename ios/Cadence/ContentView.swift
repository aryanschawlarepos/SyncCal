//
//  ContentView.swift
//  Cadence
//

import SwiftUI

/// Root view: routes between the onboarding permission gate and the calendar home.
struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var notifications: NotificationManager
    @State private var store: CalendarStore
    @State private var showLockScreenAdd = false
    @State private var lockScreenAddScope = LockScreenScope.myDay
    @State private var lockScreenAddTitle = ""
    @State private var lockScreenResumeInFlight = false
    @State private var lockScreenResumeAgain = false

    var reloadSharedStore: @MainActor () async -> Void = {}

    init(reloadSharedStore: @MainActor @escaping () async -> Void = {}) {
        let notifications = NotificationManager()
        _notifications = State(initialValue: notifications)
        _store = State(initialValue: CalendarStore(notifications: notifications))
        self.reloadSharedStore = reloadSharedStore
    }

    var body: some View {
        Group {
            if store.hasAccess {
                MainTabView(store: store, notifications: notifications)
                    .transition(.opacity)
            } else {
                PermissionGateView(store: store)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: store.hasAccess)
        .animation(.easeInOut(duration: 0.22), value: colorScheme)
        .preferredColorScheme(Theme.preferredColorScheme)
        .task {
            await notifications.refreshStatus()
            if store.hasAccess {
                store.loadCalendars()
                store.reload()
            }
            await resumeLockScreenAdd()
        }
        .onOpenURL { url in
            guard url.scheme == CadenceAppGroup.addURL.scheme,
                  url.host == CadenceAppGroup.addURL.host else {
                return
            }
            Task { await resumeLockScreenAdd() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await resumeLockScreenAdd() }
        }
        .sheet(isPresented: $showLockScreenAdd) {
            LockScreenTitlePrompt(scope: lockScreenAddScope, initialTitle: lockScreenAddTitle)
        }
    }

    @MainActor
    private func resumeLockScreenAdd() async {
        if lockScreenResumeInFlight {
            lockScreenResumeAgain = true
            return
        }
        lockScreenResumeInFlight = true
        defer { lockScreenResumeInFlight = false }
        repeat {
            lockScreenResumeAgain = false
            await reloadSharedStore()
            guard let pending = takePendingLockScreenAdd() else { continue }
            if let title = pending.title.flatMap(normalizedLockScreenTitle) {
                let saved = await finishStashedLockScreenAdd(title: title, scope: pending.scope)
                if saved {
                    continue
                }
                presentLockScreenAdd(scope: pending.scope, title: title)
                continue
            }
            presentLockScreenAdd(scope: pending.scope)
        } while lockScreenResumeAgain
    }

    private func presentLockScreenAdd(scope: LockScreenScope, title: String = "") {
        lockScreenAddScope = scope
        lockScreenAddTitle = title
        showLockScreenAdd = true
    }
}

#Preview {
    ContentView()
}
