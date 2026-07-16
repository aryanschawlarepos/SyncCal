//
//  CalendarStore.swift
//  Cadence
//

import EventKit
import SwiftUI

/// Reminder offset options offered when creating an event.
enum ReminderOffset: String, CaseIterable, Identifiable {
    case none, atTime, min5, min15, min30, hour1, day1

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .atTime: return "At time of event"
        case .min5: return "5 minutes before"
        case .min15: return "15 minutes before"
        case .min30: return "30 minutes before"
        case .hour1: return "1 hour before"
        case .day1: return "1 day before"
        }
    }

    /// Seconds before the event start. `nil` means no reminder.
    var interval: TimeInterval? {
        switch self {
        case .none: return nil
        case .atTime: return 0
        case .min5: return 5 * 60
        case .min15: return 15 * 60
        case .min30: return 30 * 60
        case .hour1: return 60 * 60
        case .day1: return 24 * 60 * 60
        }
    }
}

/// Owns the EventKit store, authorization state, calendars and the events for the visible range.
/// EventKit surfaces every calendar synced to the device — Apple (iCloud) accounts as well as
/// Google accounts the user has added in iOS Settings — so both appear here automatically.
@Observable
final class CalendarStore {
    private let eventStore = EKEventStore()
    private let notifications: NotificationManager

    var authorizationStatus: EKAuthorizationStatus
    var calendars: [EKCalendar] = []
    var hiddenCalendarIDs: Set<String> = []
    var events: [EventItem] = []

    var displayedMonth: Date = Date().startOfMonth
    var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    init(notifications: NotificationManager) {
        self.notifications = notifications
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    var hasAccess: Bool {
        authorizationStatus == .fullAccess || authorizationStatus == .authorized
    }

    // MARK: - Authorization

    func requestAccess() async {
        do {
            _ = try await eventStore.requestFullAccessToEvents()
        } catch {
            // User declined or an error occurred; status reflects the outcome.
        }
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if hasAccess {
            loadCalendars()
            reload()
        }
    }

    // MARK: - Loading

    func loadCalendars() {
        calendars = eventStore.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// Fetches events across the whole visible month grid so any selected day has data.
    func reload() {
        guard hasAccess else { return }
        let range = displayedMonth.monthGridRange
        let active = calendars.filter { !hiddenCalendarIDs.contains($0.calendarIdentifier) }
        guard !active.isEmpty else { events = []; return }

        let predicate = eventStore.predicateForEvents(
            withStart: range.start,
            end: range.end,
            calendars: active
        )
        events = eventStore.events(matching: predicate)
            .map { ekEvent in
                EventItem(
                    id: ekEvent.eventIdentifier ?? UUID().uuidString,
                    title: ekEvent.title ?? "Untitled",
                    startDate: ekEvent.startDate,
                    endDate: ekEvent.endDate,
                    isAllDay: ekEvent.isAllDay,
                    calendarTitle: ekEvent.calendar.title,
                    sourceTitle: ekEvent.calendar.source.title,
                    colorHex: Self.hex(from: ekEvent.calendar.cgColor),
                    location: ekEvent.location,
                    notes: ekEvent.notes
                )
            }
            .sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Queries

    func events(on day: Date) -> [EventItem] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        return events.filter { event in
            // An event belongs to the day if its span overlaps the day's [start, end) window.
            event.startDate < dayEnd && event.endDate >= dayStart
        }
    }

    /// Days in the current month that contain at least one event (for the grid dots).
    func eventCounts() -> [Date: Int] {
        let cal = Calendar.current
        var counts: [Date: Int] = [:]
        for event in events {
            let day = cal.startOfDay(for: event.startDate)
            counts[day, default: 0] += 1
        }
        return counts
    }

    var writableCalendars: [EKCalendar] {
        calendars.filter { $0.allowsContentModifications }
    }

    var defaultCalendar: EKCalendar? {
        eventStore.defaultCalendarForNewEvents ?? writableCalendars.first
    }

    // MARK: - Mutations

    func createEvent(
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        calendar: EKCalendar,
        location: String?,
        notes: String?,
        reminder: ReminderOffset
    ) throws {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = start
        event.endDate = end
        event.isAllDay = isAllDay
        event.calendar = calendar
        event.location = location
        event.notes = notes
        if let interval = reminder.interval {
            event.addAlarm(EKAlarm(relativeOffset: -interval))
        }
        try eventStore.save(event, span: .thisEvent)

        // Cadence also schedules its own branded reminder notification.
        if let interval = reminder.interval {
            let fireDate = start.addingTimeInterval(-interval)
            notifications.schedule(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: title,
                body: reminderBody(for: reminder, start: start, isAllDay: isAllDay),
                fireDate: fireDate
            )
        }
        reload()
    }

    func deleteEvent(id: String) {
        guard let event = eventStore.event(withIdentifier: id) else { return }
        try? eventStore.remove(event, span: .thisEvent)
        notifications.cancel(id: id)
        reload()
    }

    private func reminderBody(for reminder: ReminderOffset, start: Date, isAllDay: Bool) -> String {
        if reminder == .atTime { return "Starting now" }
        let formatter = DateFormatter()
        formatter.dateFormat = isAllDay ? "EEEE, MMM d" : "h:mm a"
        return "Coming up at \(formatter.string(from: start))"
    }

    private static func hex(from cgColor: CGColor?) -> UInt {
        guard let cgColor, let components = cgColor.components, components.count >= 3 else {
            return 0xF5B841
        }
        let r = UInt(max(0, min(1, components[0])) * 255)
        let g = UInt(max(0, min(1, components[1])) * 255)
        let b = UInt(max(0, min(1, components[2])) * 255)
        return (r << 16) | (g << 8) | b
    }
}