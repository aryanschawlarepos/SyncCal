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
    @State private var accessAlertMessage: String?
    @State private var shouldOfferSettings = false
    @State private var hasAppeared = false

    private var isDenied: Bool {
        store.authorizationStatus == .denied
            || store.authorizationStatus == .restricted
            || store.authorizationStatus == .writeOnly
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Theme.glow.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                header
                    .padding(.horizontal, 24)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 12)

                calendarPreview
                    .padding(.horizontal, 24)
                    .padding(.top, 30)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 18)

                featureList
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)

                Spacer(minLength: 24)

                cta
                    .padding(.horizontal, 20)
                    .padding(.bottom, isDenied ? 8 : 20)

                if isDenied {
                    Text("Calendar access is off. You can restore Full Access in Settings.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.84).delay(0.05)) {
                hasAppeared = true
            }
        }
        .alert("Calendar access needed", isPresented: accessAlertBinding) {
            Button("OK", role: .cancel) {}

            if shouldOfferSettings {
                Button("Open Settings") {
                    openSettings()
                }
            }
        } message: {
            Text(accessAlertMessage ?? "Cadence needs Full Calendar Access to show and create events.")
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            Label("Private by design", systemImage: "lock.shield")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.coolAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Theme.coolAccent.opacity(0.13), in: .capsule)
                .overlay(Capsule().stroke(Theme.coolAccent.opacity(0.24), lineWidth: 1))

            Text("Your calendar, composed.")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.82)

            Text("Cadence brings your Apple and Google calendars into one quiet place for planning, reminders, and focus.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 330)
        }
    }

    private var calendarPreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Today")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                    Text("Wednesday")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                }

                Spacer()

                Image(systemName: "calendar")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 38, height: 38)
                    .background(Theme.accentSoft, in: .circle)
            }

            VStack(spacing: 10) {
                previewEvent(title: "Design review", time: "9:30 AM", tint: Theme.accent)
                previewEvent(title: "Focus block", time: "11:00 AM", tint: Theme.coolAccent)
                previewEvent(title: "Dinner", time: "7:00 PM", tint: Color(hex: 0xB6A7FF))
            }
        }
        .padding(18)
        .background(Theme.surfaceGradient, in: .rect(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.strokeSoft, lineWidth: 1)
        )
        .shadow(color: Theme.shadow, radius: 22, y: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sample calendar preview")
    }

    private func previewEvent(title: String, time: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(tint)
                .frame(width: 4, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(time)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()
        }
        .padding(12)
        .background(tint.opacity(0.11), in: .rect(cornerRadius: 14))
    }

    private var featureList: some View {
        VStack(spacing: 10) {
            ForEach(features, id: \.title) { feature in
                HStack(spacing: 14) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(feature.tint)
                        .frame(width: 34, height: 34)
                        .background(feature.tint.opacity(0.13), in: .circle)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(feature.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Text(feature.subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Spacer()
                }
                .padding(14)
                .background(Theme.surface.opacity(0.76), in: .rect(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Theme.strokeSoft, lineWidth: 1)
                )
            }
        }
    }

    private var cta: some View {
        Button(action: primaryAction) {
            HStack(spacing: 10) {
                if isRequesting {
                    ProgressView()
                        .tint(Theme.onAccent)
                } else {
                    Image(systemName: isDenied ? "gearshape.fill" : "calendar.badge.plus")
                        .font(.system(size: 17, weight: .bold))
                        .symbolRenderingMode(.hierarchical)
                }

                Text(buttonTitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Theme.accentGradient, in: .rect(cornerRadius: 18))
            .shadow(color: Theme.accent.opacity(isRequesting ? 0.18 : 0.34), radius: 18, y: 8)
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(isRequesting)
        .opacity(isRequesting ? 0.86 : 1)
        .accessibilityLabel(buttonTitle)
    }

    private let features: [(icon: String, title: String, subtitle: String, tint: Color)] = [
        ("rectangle.stack.fill", "One place for every calendar", "Apple and Google calendars sync through iOS.", Theme.accent),
        ("bolt.fill", "Add plans fast", "Create events with reminders in a few focused taps.", Theme.coolAccent),
        ("bell.badge.fill", "Stay ahead", "Cadence keeps upcoming moments easy to notice.", Color(hex: 0xB6A7FF))
    ]

    private func primaryAction() {
        guard !isRequesting else { return }

        if isDenied {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            openSettings()
        } else {
            isRequesting = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            Task {
                let result = await store.requestAccess()
                isRequesting = false

                switch result {
                case .granted:
                    accessAlertMessage = nil
                    shouldOfferSettings = false
                case .needsSettings(let message):
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    shouldOfferSettings = true
                    accessAlertMessage = message
                case .unavailable(let message):
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    shouldOfferSettings = false
                    accessAlertMessage = message
                }
            }
        }
    }

    private var buttonTitle: String {
        if isRequesting { return "Connecting..." }
        return isDenied ? "Open Settings" : "Connect my calendars"
    }

    private var accessAlertBinding: Binding<Bool> {
        Binding(
            get: { accessAlertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    accessAlertMessage = nil
                    shouldOfferSettings = false
                }
            }
        )
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            accessAlertMessage = "Settings could not be opened. Open the Settings app manually and allow Full Calendar Access for Cadence."
            return
        }

        UIApplication.shared.open(url) { didOpen in
            if !didOpen {
                accessAlertMessage = "Settings could not be opened. Open the Settings app manually and allow Full Calendar Access for Cadence."
            }
        }
    }
}
