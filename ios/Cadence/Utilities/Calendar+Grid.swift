//
//  Calendar+Grid.swift
//  Cadence
//

import Foundation

extension Date {
    /// First moment of this date's month.
    var startOfMonth: Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: self)) ?? self
    }

    /// Inclusive start / exclusive end covering the full 6-week grid for this month.
    var monthGridRange: (start: Date, end: Date) {
        let cal = Calendar.current
        let days = monthGridDays
        let start = cal.startOfDay(for: days.first ?? self)
        let last = days.last ?? self
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: last)) ?? last
        return (start, end)
    }

    /// The 42 days (6 weeks) shown in a month grid, including leading/trailing days.
    var monthGridDays: [Date] {
        let cal = Calendar.current
        let monthStart = startOfMonth
        let weekday = cal.component(.weekday, from: monthStart)
        let leading = (weekday - cal.firstWeekday + 7) % 7

        guard let gridStart = cal.date(byAdding: .day, value: -leading, to: monthStart) else {
            return []
        }
        return (0 ..< 42).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: gridStart)
        }
    }
}

extension Calendar {
    /// Localized single-letter weekday symbols ordered from `firstWeekday`.
    var orderedWeekdaySymbols: [String] {
        let symbols = veryShortStandaloneWeekdaySymbols
        let shift = firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
}
