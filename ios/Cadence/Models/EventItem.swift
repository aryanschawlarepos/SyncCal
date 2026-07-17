//
//  EventItem.swift
//  Cadence
//

import SwiftUI

enum CalendarItemSource: String, Hashable {
    case local
    case apple
    case google

    var label: String {
        switch self {
        case .local: return "Cadence"
        case .apple: return "Apple Calendar"
        case .google: return "Google Calendar"
        }
    }
}

/// Lightweight, view-friendly representation of a calendar event decoupled from EventKit.
struct EventItem: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String
    let sourceTitle: String
    let colorHex: UInt
    let location: String?
    let notes: String?
    let source: CalendarItemSource
    let sourceId: String
    let editable: Bool

    var tint: Color { Color(hex: colorHex) }

    var timeLabel: String {
        if isAllDay { return "All-day" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startDate)
    }

    var rangeLabel: String {
        if isAllDay { return "All-day" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }
}
