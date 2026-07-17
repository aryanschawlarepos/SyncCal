//
//  CalendarStore.swift
//  Cadence
//

import EventKit
import OSLog
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

enum CalendarAccessResult: Equatable {
    case granted
    case needsSettings(String)
    case unavailable(String)
}

enum CalendarStoreError: LocalizedError {
    case eventNotFound
    case readOnlyCalendar

    var errorDescription: String? {
        switch self {
        case .eventNotFound:
            return "Cadence could not find this event. It may have been moved or deleted in the source calendar."
        case .readOnlyCalendar:
            return "Changes to this event must be made in the original calendar."
        }
    }
}

/// Owns the EventKit store, authorization state, calendars and the events for the visible range.
/// EventKit surfaces every calendar synced to the device — Apple (iCloud) accounts as well as
/// Google accounts the user has added in iOS Settings — so both appear here automatically.
@Observable
@MainActor
final class CalendarStore {
    private static let logger = Logger(subsystem: "com.rork.Cadence", category: "CalendarStore")

    private let eventStore = EKEventStore()
    private let notifications: NotificationManager

    var authorizationStatus: EKAuthorizationStatus
    var calendars: [EKCalendar] = []
    var hiddenCalendarIDs: Set<String> = []
    var events: [EventItem] = []
    var upcomingEvents: [EventItem] = []
    var accessErrorMessage: String?
    private var eventsByDay: [Date: [EventItem]] = [:]
    private var eventCountsByDay: [Date: Int] = [:]

    var displayedMonth: Date = Date().startOfMonth
    var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    init(notifications: NotificationManager) {
        self.notifications = notifications
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    var hasAccess: Bool {
        switch authorizationStatus {
        case .fullAccess:
            return true
        case .authorized:
            return true
        default:
            return false
        }
    }

    // MARK: - Authorization

    @discardableResult
    func requestAccess() async -> CalendarAccessResult {
        Self.logger.info("Calendar access request started. Current status: \(String(describing: self.authorizationStatus), privacy: .public)")

        switch authorizationStatus {
        case .fullAccess, .authorized:
            accessErrorMessage = nil
            loadCalendars()
            reload()
            Self.logger.info("Calendar access already granted. Status: \(String(describing: self.authorizationStatus), privacy: .public)")
            return .granted
        case .denied, .restricted:
            let message = settingsAccessMessage(for: authorizationStatus)
            accessErrorMessage = message
            Self.logger.warning("Calendar access cannot be requested in-app. Status: \(String(describing: self.authorizationStatus), privacy: .public)")
            return .needsSettings(message)
        case .notDetermined, .writeOnly:
            break
        @unknown default:
            Self.logger.warning("Calendar access request continuing for unknown status: \(String(describing: self.authorizationStatus), privacy: .public)")
        }

        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)

            Self.logger.info("Calendar access request finished. Granted: \(granted, privacy: .public), status: \(String(describing: self.authorizationStatus), privacy: .public)")

            guard granted, hasAccess else {
                let message = messageAfterUnsuccessfulRequest(status: authorizationStatus)
                accessErrorMessage = message

                if authorizationStatus == .denied || authorizationStatus == .restricted {
                    return .needsSettings(message)
                }

                return .unavailable(message)
            }

            accessErrorMessage = nil
            loadCalendars()
            reload()
            return .granted
        } catch {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            accessErrorMessage = calendarAccessMessage(for: error)
            Self.logger.error("Calendar access request failed: \(error.localizedDescription, privacy: .public)")

            if authorizationStatus == .denied || authorizationStatus == .restricted {
                return .needsSettings(accessErrorMessage ?? settingsAccessMessage(for: authorizationStatus))
            }

            return .unavailable(accessErrorMessage ?? error.localizedDescription)
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
        loadEvents(from: range.start, to: range.end)
    }

    /// Fetches events for a single day without changing the visible calendar month.
    func reloadEvents(for day: Date) {
        guard hasAccess else { return }
        let dayStart = Calendar.current.startOfDay(for: day)
        guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else { return }
        loadEvents(from: dayStart, to: dayEnd)
    }

    /// Fetches a rolling agenda window for Upcoming without changing the visible calendar month cache.
    func reloadUpcomingEvents(daysAhead: Int = 120) {
        guard hasAccess else { return }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: daysAhead, to: start) ?? start.addingTimeInterval(10_368_000)
        upcomingEvents = fetchEvents(from: start, to: end)
    }

    private func loadEvents(from start: Date, to end: Date) {
        events = fetchEvents(from: start, to: end)
        rebuildEventIndexes()
    }

    private func fetchEvents(from start: Date, to end: Date) -> [EventItem] {
        let active = calendars.filter { !hiddenCalendarIDs.contains($0.calendarIdentifier) }
        guard !active.isEmpty else { return [] }

        let predicate = eventStore.predicateForEvents(
            withStart: start,
            end: end,
            calendars: active
        )
        return eventStore.events(matching: predicate)
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
                    notes: ekEvent.notes,
                    source: Self.source(for: ekEvent.calendar.source.title),
                    sourceId: ekEvent.eventIdentifier ?? ekEvent.calendarItemIdentifier,
                    editable: ekEvent.calendar.allowsContentModifications
                )
            }
            .sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Queries

    func events(on day: Date) -> [EventItem] {
        let dayStart = Calendar.current.startOfDay(for: day)
        return eventsByDay[dayStart, default: []]
    }

    /// Days in the current month that contain at least one event (for the grid dots).
    func eventCounts() -> [Date: Int] {
        eventCountsByDay
    }

    private func rebuildEventIndexes() {
        let cal = Calendar.current
        var eventsByDay: [Date: [EventItem]] = [:]
        var counts: [Date: Int] = [:]

        for event in events {
            var day = cal.startOfDay(for: event.startDate)
            let lastDay = cal.startOfDay(for: event.endDate)

            while day <= lastDay {
                counts[day, default: 0] += 1
                eventsByDay[day, default: []].append(event)
                guard let nextDay = cal.date(byAdding: .day, value: 1, to: day) else { break }
                day = nextDay
            }
        }

        self.eventsByDay = eventsByDay.mapValues { $0.sorted { $0.startDate < $1.startDate } }
        eventCountsByDay = counts
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
        reloadUpcomingEvents()
    }

    func updateEvent(
        id: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        calendar: EKCalendar,
        location: String?,
        notes: String?,
        reminder: ReminderOffset
    ) throws {
        guard let event = eventStore.event(withIdentifier: id) else {
            Self.logger.error("Event update failed because EventKit could not resolve identifier: \(id, privacy: .public)")
            throw CalendarStoreError.eventNotFound
        }

        guard event.calendar.allowsContentModifications, calendar.allowsContentModifications else {
            Self.logger.warning("Event update blocked by read-only calendar. Event id: \(id, privacy: .public)")
            throw CalendarStoreError.readOnlyCalendar
        }

        event.title = title
        event.startDate = start
        event.endDate = end
        event.isAllDay = isAllDay
        event.calendar = calendar
        event.location = location
        event.notes = notes

        for alarm in event.alarms ?? [] {
            event.removeAlarm(alarm)
        }
        if let interval = reminder.interval {
            event.addAlarm(EKAlarm(relativeOffset: -interval))
        }

        try eventStore.save(event, span: .thisEvent)
        notifications.cancel(id: id)

        if let interval = reminder.interval {
            let fireDate = start.addingTimeInterval(-interval)
            notifications.schedule(
                id: event.eventIdentifier ?? id,
                title: title,
                body: reminderBody(for: reminder, start: start, isAllDay: isAllDay),
                fireDate: fireDate
            )
        }

        Self.logger.info("Event updated successfully. Event id: \(id, privacy: .public)")
        reload()
        reloadUpcomingEvents()
    }

    func deleteEvent(id: String) throws {
        guard let event = eventStore.event(withIdentifier: id) else {
            Self.logger.error("Event delete failed because EventKit could not resolve identifier: \(id, privacy: .public)")
            throw CalendarStoreError.eventNotFound
        }
        guard event.calendar.allowsContentModifications else {
            Self.logger.warning("Event delete blocked by read-only calendar. Event id: \(id, privacy: .public)")
            throw CalendarStoreError.readOnlyCalendar
        }
        try eventStore.remove(event, span: .thisEvent)
        notifications.cancel(id: id)
        Self.logger.info("Event deleted successfully. Event id: \(id, privacy: .public)")
        reload()
        reloadUpcomingEvents()
    }

    private func reminderBody(for reminder: ReminderOffset, start: Date, isAllDay: Bool) -> String {
        if reminder == .atTime { return "Starting now" }
        let formatter = DateFormatter()
        formatter.dateFormat = isAllDay ? "EEEE, MMM d" : "h:mm a"
        return "Coming up at \(formatter.string(from: start))"
    }

    private func calendarAccessMessage(for error: Error) -> String {
        let nsError = error as NSError

        if nsError.domain == "EKErrorDomain" {
            return "Cadence could not show the calendar permission prompt. Confirm the app includes the Full Calendar Access privacy description, then rebuild and try again."
        }

        return error.localizedDescription
    }

    private func messageAfterUnsuccessfulRequest(status: EKAuthorizationStatus) -> String {
        switch status {
        case .denied:
            return settingsAccessMessage(for: status)
        case .restricted:
            return settingsAccessMessage(for: status)
        case .writeOnly:
            return "Cadence has write-only calendar access, but needs Full Access to show your existing events. Allow Full Access in Settings."
        case .notDetermined:
            return "Cadence could not show the calendar permission prompt. Confirm the app includes the Full Calendar Access privacy description, then rebuild and try again."
        default:
            return "Calendar access was not granted."
        }
    }

    private func settingsAccessMessage(for status: EKAuthorizationStatus) -> String {
        switch status {
        case .restricted:
            return "Calendar access is restricted on this device. Check Screen Time, device management, or parental controls."
        case .writeOnly:
            return "Cadence needs Full Calendar Access to show your existing events. Allow Full Access in Settings."
        default:
            return "Calendar access was not granted. Open Settings and allow Full Access for Cadence."
        }
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

    private static func source(for title: String) -> CalendarItemSource {
        title.localizedCaseInsensitiveContains("google") ? .google : .apple
    }
}
