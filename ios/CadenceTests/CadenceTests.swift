//
//  CadenceTests.swift
//  CadenceTests
//
//  Created by Rork on July 16, 2026.
//

import Testing
@testable import Cadence

struct CadenceTests {

    @Test func plannerDefaultsToWorkdayWhenThereAreNoTimedEvents() {
        let day = date(hour: 12)

        let bounds = PlannerTimeline.bounds(for: [], day: day)

        #expect(bounds.lowerBound == date(hour: 8))
        #expect(bounds.upperBound == date(hour: 20))
    }

    @Test func plannerExpandsToIncludeEventsOutsideWorkday() {
        let early = event(startHour: 7, endHour: 8)
        let late = event(startHour: 19, endHour: 22)

        let bounds = PlannerTimeline.bounds(for: [early, late], day: date(hour: 12))

        #expect(bounds.lowerBound == date(hour: 7))
        #expect(bounds.upperBound == date(hour: 22))
    }

    @Test func plannerStopsAtLastTimedEventWhenItEndsBeforeEightPM() {
        let event = event(startHour: 9, endHour: 11)

        let bounds = PlannerTimeline.bounds(for: [event], day: date(hour: 12))

        #expect(bounds.lowerBound == date(hour: 8))
        #expect(bounds.upperBound == date(hour: 11))
    }

    @Test func allDayEventsDoNotExpandTimedTimeline() {
        let allDay = event(startHour: 0, endHour: 24, isAllDay: true)

        let bounds = PlannerTimeline.bounds(for: [allDay], day: date(hour: 12))

        #expect(bounds.lowerBound == date(hour: 8))
        #expect(bounds.upperBound == date(hour: 20))
    }

    private func date(hour: Int) -> Date {
        Calendar.current.date(
            bySettingHour: hour % 24,
            minute: 0,
            second: 0,
            of: Calendar.current.startOfDay(for: Date())
        )!
    }

    private func event(startHour: Int, endHour: Int, isAllDay: Bool = false) -> EventItem {
        EventItem(
            id: UUID().uuidString,
            title: "Test event",
            startDate: date(hour: startHour),
            endDate: date(hour: endHour),
            isAllDay: isAllDay,
            calendarTitle: "Test calendar",
            sourceTitle: "Test source",
            colorHex: 0xF5B841,
            location: nil,
            notes: nil
        )
    }

}
