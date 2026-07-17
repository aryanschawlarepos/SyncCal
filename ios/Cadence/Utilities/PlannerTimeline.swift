//
//  PlannerTimeline.swift
//  Cadence
//

import Foundation

/// Calculates the smallest useful workday range for the Planner timeline.
enum PlannerTimeline {
    static func bounds(
        for events: [EventItem],
        day: Date,
        calendar: Calendar = .current
    ) -> ClosedRange<Date> {
        let dayStart = calendar.startOfDay(for: day)
        let workdayStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: dayStart)!
        let workdayEnd = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: dayStart)!

        let timedEvents = events.filter { !$0.isAllDay }
        let earliestStart = timedEvents.map(\.startDate).min() ?? workdayStart
        let latestEnd = timedEvents.map(\.endDate).max() ?? workdayEnd

        return min(workdayStart, earliestStart)...latestEnd
    }
}
