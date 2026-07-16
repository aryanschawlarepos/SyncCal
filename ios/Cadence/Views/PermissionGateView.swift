//
//  PermissionGateView.swift
//  Cadence
//

import EventKit
import SwiftUI

/// Onboarding screen shown until calendar access is granted.
struct PermissionGateView: View {
    let store: CalendarStore
    @State private var isRequesting = false

    private var isDenied: Bool {
        store.authorizationStatus == .denied || store.authorizationStatus == .restricted
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Theme.glow.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Theme.accentSoft)
                        .frame(width: 132, height: 132)
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 54, weight: .medium))
                        .foregroundStyle(Theme.accentGradient)
                }
                .padding(.bottom, 32)

                Text("Everything in one\nrhythm")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textPrimary)

                Text("Cadence brings your Apple and Google calendars together in one calm, dark space — with reminders that keep you on beat.")
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 36)
                    .padding(.top, 12)

                Spacer()

                VStack(spacing: 14) {
                    ForEach(features, id: \.title) { feature in
                        HStack(spacing: 14) {
                            Image(systemName: feature.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feature.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(feature.subtitle)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(20)
                .background(Theme.surface, in: .rect(cornerRadius: 20))
                .padding(.horizontal, 20)

                Spacer()

                Button(action: primaryAction) {
                    Text(isDenied ? "Open Settings" : "Connect my calendars")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Theme.accentGradient, in: .rect(cornerRadius: 18))
                        .shadow(color: Theme.accent.opacity(0.3), radius: 16, y: 6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                if isDenied {
                    Text("Calendar access is off. Enable it in Settings to continue.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 16)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("calendar", "Apple & Google", "All your accounts, unified"),
        ("bolt.fill", "Fast event creation", "Add plans in a couple taps"),
        ("bell.badge.fill", "Smart reminders", "Never miss a beat")
    ]

    private func primaryAction() {
        if isDenied {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } else {
            Task { await store.requestAccess() }
        }
    }
}
