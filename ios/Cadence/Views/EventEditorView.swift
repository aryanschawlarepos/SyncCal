//
//  EventEditorView.swift
//  Cadence
//

import EventKit
import SwiftUI

/// Fast, focused event-creation sheet.
struct EventEditorView: View {
    let store: CalendarStore
    let notifications: NotificationManager
    let initialDate: Date

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var isAllDay = false
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var reminder: ReminderOffset = .min15
    @State private var selectedCalendar: EKCalendar?
    @State private var showNotificationDeniedAlert = false

    init(store: CalendarStore, notifications: NotificationManager, initialDate: Date) {
        self.store = store
        self.notifications = notifications
        self.initialDate = initialDate

        let calendar = Calendar.current
        let now = Date()
        // Start at the next round hour on the selected day.
        let base = calendar.date(
            bySettingHour: calendar.component(.hour, from: now) + 1,
            minute: 0,
            second: 0,
            of: initialDate
        ) ?? initialDate
        _startDate = State(initialValue: base)
        _endDate = State(initialValue: base.addingTimeInterval(3600))
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && selectedCalendar != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    titleCard
                    scheduleCard
                    calendarCard
                    reminderCard
                    detailsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(canSave ? Theme.accent : Theme.textTertiary)
                        .disabled(!canSave)
                }
            }
            .onChange(of: startDate) { _, newValue in
                if endDate <= newValue {
                    endDate = newValue.addingTimeInterval(3600)
                }
            }
            .onChange(of: reminder) { _, newValue in
                if newValue != .none {
                    Task { await ensureNotificationPermission() }
                }
            }
            .onAppear {
                if selectedCalendar == nil {
                    selectedCalendar = store.defaultCalendar
                }
            }
            .alert("Reminders are off", isPresented: $showNotificationDeniedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Enable notifications for Cadence in Settings to receive reminders. Your event will still save.")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Cards

    private var titleCard: some View {
        TextField("", text: $title, prompt: Text("Event title").foregroundStyle(Theme.textTertiary))
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .padding(18)
            .background(Theme.surface, in: .rect(cornerRadius: 16))
    }

    private var scheduleCard: some View {
        Card {
            Toggle(isOn: $isAllDay) {
                Label("All-day", systemImage: "sun.max")
                    .foregroundStyle(Theme.textPrimary)
            }
            .tint(Theme.accent)

            Divider().overlay(Theme.stroke)

            DatePicker(
                "Starts",
                selection: $startDate,
                displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .foregroundStyle(Theme.textPrimary)

            DatePicker(
                "Ends",
                selection: $endDate,
                in: startDate...,
                displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .foregroundStyle(Theme.textPrimary)
        }
        .tint(Theme.accent)
    }

    private var calendarCard: some View {
        Card {
            Menu {
                ForEach(store.writableCalendars, id: \.calendarIdentifier) { cal in
                    Button {
                        selectedCalendar = cal
                    } label: {
                        Label("\(cal.title) · \(cal.source.title)", systemImage: "circle.fill")
                    }
                }
            } label: {
                HStack {
                    Label("Calendar", systemImage: "calendar")
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if let cal = selectedCalendar {
                        Circle()
                            .fill(Color(hex: hex(cal.cgColor)))
                            .frame(width: 10, height: 10)
                        Text(cal.title)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    private var reminderCard: some View {
        Card {
            Menu {
                ForEach(ReminderOffset.allCases) { offset in
                    Button(offset.label) { reminder = offset }
                }
            } label: {
                HStack {
                    Label("Reminder", systemImage: "bell")
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(reminder.label)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    private var detailsCard: some View {
        Card {
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse").foregroundStyle(Theme.textTertiary)
                TextField("", text: $location, prompt: Text("Location").foregroundStyle(Theme.textTertiary))
                    .foregroundStyle(Theme.textPrimary)
            }
            Divider().overlay(Theme.stroke)
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "text.alignleft").foregroundStyle(Theme.textTertiary)
                TextField("", text: $notes, prompt: Text("Notes").foregroundStyle(Theme.textTertiary), axis: .vertical)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1 ... 4)
            }
        }
    }

    // MARK: - Actions

    private func ensureNotificationPermission() async {
        await notifications.refreshStatus()
        if !notifications.isAuthorized {
            let granted = await notifications.requestAuthorization()
            if !granted { showNotificationDeniedAlert = true }
        }
    }

    private func save() {
        guard let calendar = selectedCalendar else { return }
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        do {
            try store.createEvent(
                title: trimmed,
                start: startDate,
                end: isAllDay ? startDate : endDate,
                isAllDay: isAllDay,
                calendar: calendar,
                location: location.isEmpty ? nil : location,
                notes: notes.isEmpty ? nil : notes,
                reminder: reminder
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func hex(_ cgColor: CGColor?) -> UInt {
        guard let components = cgColor?.components, components.count >= 3 else { return 0xF5B841 }
        let r = UInt(max(0, min(1, components[0])) * 255)
        let g = UInt(max(0, min(1, components[1])) * 255)
        let b = UInt(max(0, min(1, components[2])) * 255)
        return (r << 16) | (g << 8) | b
    }
}

/// Rounded surface container used by the editor cards.
private struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 12) {
            content
        }
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: 16))
    }
}
