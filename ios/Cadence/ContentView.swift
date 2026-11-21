//
//  ContentView.swift
//  Cadence
//

import SwiftUI

/// Root view: routes between the onboarding permission gate and the calendar home.
struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var notifications = NotificationManager()
    @State private var store: CalendarStore
    @State private var showLockScreenAdd = false
    @State private var lockScreenAddScope = LockScreenScope.myDay

    init() {
        let notifications = NotificationManager()
        _notifications = State(initialValue: notifications)
        _store = State(initialValue: CalendarStore(notifications: notifications))
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
            presentStoredLockScreenAdd()
        }
        .onOpenURL { url in
            presentLockScreenAdd(from: url)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            presentStoredLockScreenAdd()
        }
        .sheet(isPresented: $showLockScreenAdd) {
            LockScreenTitlePrompt(scope: lockScreenAddScope)
        }
    }

    private func presentStoredLockScreenAdd() {
        guard let scope = storedLockScreenAddScope() else { return }
        presentLockScreenAdd(scope: scope)
    }

    private func presentLockScreenAdd(from url: URL) {
        guard url.scheme != "cadence-internal" else { return }
        guard url.scheme == CadenceAppGroup.addURL.scheme,
              url.host == CadenceAppGroup.addURL.host else {
            return
        }
        if let scope = storedLockScreenAddScope() {
            presentLockScreenAdd(scope: scope)
            return
        }
        if showLockScreenAdd {
            return
        }
        presentLockScreenAdd(scope: .myDay)
    }

    private func presentLockScreenAdd(scope: LockScreenScope) {
        lockScreenAddScope = scope
        showLockScreenAdd = true
    }

    private func storedLockScreenAddScope() -> LockScreenScope? {
        guard let raw = UserDefaults(suiteName: CadenceAppGroup.identifier)?
            .string(forKey: CadenceAppGroup.fallbackScopeKey) else {
            return nil
        }
        return LockScreenScope.scope(id: raw) ?? .myDay
    }
}

#Preview {
    ContentView()
}
