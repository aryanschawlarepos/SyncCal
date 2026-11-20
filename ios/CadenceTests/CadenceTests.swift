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

    @Test func fewerThanThreeOpenTasksStillShow() {
        let tasks = [source("Milk", due: today), source("Email", due: today)]

        let card = resolveLockScreenCard(scope: .myDay, tasks: tasks, currentIDs: [], today: today, calendar: calendar)

        #expect(card == .showing(rows: [row("Milk"), row("Email")], openCount: 2))
    }

    @Test func openCountIncludesTasksWaitingOffTheCard() {
        let tasks = (1...4).map { source("T\($0)", due: today, createdHour: $0) }

        let card = resolveLockScreenCard(scope: .myDay, tasks: tasks, currentIDs: [], today: today, calendar: calendar)

        guard case .showing(let rows, let openCount) = card else {
            Issue.record("expected a card")
            return
        }
        #expect(rows.map(\.title) == ["T4", "T3", "T2"])
        #expect(openCount == 4)
    }

    @Test func completedRowStaysAndDoesNotBackfill() {
        let milk = source("Milk", due: today)
        let call = source("Call", due: today, completed: true)
        let email = source("Email", due: today)
        let later = source("Later", due: today)
        let ids = [milk.id, call.id, email.id]

        let card = resolveLockScreenCard(scope: .myDay, tasks: [milk, call, email, later], currentIDs: ids, today: today, calendar: calendar)

        #expect(card == .showing(rows: [row("Milk"), row("Call", completed: true), row("Email")], openCount: 3))
    }

    @Test func deletedRowDropsWithoutBackfill() {
        let milk = source("Milk", due: today)
        let email = source("Email", due: today)
        let later = source("Later", due: today)
        let missing = UUID()

        let card = resolveLockScreenCard(scope: .myDay, tasks: [milk, email, later], currentIDs: [milk.id, missing, email.id], today: today, calendar: calendar)

        #expect(card == .showing(rows: [row("Milk"), row("Email")], openCount: 3))
    }

    @Test func batchAdvancesOnlyWhenEveryRemainingRowIsCrossedOut() {
        let done = (1...3).map { source("D\($0)", due: today, completed: true, createdHour: $0) }
        let next = [source("N1", due: today, createdHour: 4), source("N2", due: today, createdHour: 5)]

        let card = resolveLockScreenCard(scope: .myDay, tasks: done + next, currentIDs: done.map(\.id), today: today, calendar: calendar)

        #expect(card == .showing(rows: [row("N2"), row("N1")], openCount: 2))
    }

    @Test func finishedBatchStaysAndDoesNotEndTheActivity() {
        let done = [source("Milk", due: today, completed: true), source("Call", due: today, completed: true)]

        let card = resolveLockScreenCard(scope: .myDay, tasks: done, currentIDs: done.map(\.id), today: today, calendar: calendar)

        #expect(card == .showing(rows: [row("Milk", completed: true), row("Call", completed: true)], openCount: 0))
        #expect(lockScreenActivityCommand(state: card, isRunning: true) == .update)
    }

    @Test func newTaskWaitsUntilTheBatchIsFinished() {
        let milk = source("Milk", due: today)
        let extra = source("Extra", due: today)

        let card = resolveLockScreenCard(scope: .myDay, tasks: [milk, extra], currentIDs: [milk.id], today: today, calendar: calendar)

        #expect(card == .showing(rows: [row("Milk")], openCount: 2))
    }

    @Test func newTaskReplacesAFinishedBatch() {
        let done = source("Milk", due: today, completed: true)
        let extra = source("Extra", due: today)

        let card = resolveLockScreenCard(scope: .myDay, tasks: [done, extra], currentIDs: [done.id], today: today, calendar: calendar)

        #expect(card == .showing(rows: [row("Extra")], openCount: 1))
    }

    @Test func taskThatLeavesTheScopeDropsOff() {
        let list = UUID()
        let stayed = source("Stay", list: list)
        let moved = source("Moved", list: UUID())
        let waiting = source("Wait", list: list)

        let card = resolveLockScreenCard(scope: .list(list), tasks: [stayed, moved, waiting], currentIDs: [stayed.id, moved.id], today: today, calendar: calendar)

        #expect(card == .showing(rows: [row("Stay")], openCount: 2))
    }

    @Test func myDayDropsATaskWhoseDueDateIsNoLongerToday() {
        let stayed = source("Stay", due: today)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let left = source("Left", due: tomorrow, completed: true)

        let card = resolveLockScreenCard(scope: .myDay, tasks: [stayed, left], currentIDs: [stayed.id, left.id], today: today, calendar: calendar)

        #expect(card == .showing(rows: [row("Stay")], openCount: 1))
    }

    @Test func emptyScopeEndsARunningActivityAndSkipsANewOne() {
        let card = resolveLockScreenCard(scope: .myDay, tasks: [], currentIDs: [], today: today, calendar: calendar)

        #expect(card == .ended)
        #expect(lockScreenActivityCommand(state: card, isRunning: true) == .end)
        #expect(lockScreenActivityCommand(state: card, isRunning: false) == .skip)
    }

    @Test func whitespaceTitleIsIgnoredAndARealTitleIsTrimmed() {
        #expect(normalizedLockScreenTitle("   ") == nil)
        #expect(normalizedLockScreenTitle("\n") == nil)
        #expect(normalizedLockScreenTitle("  Milk  ") == "Milk")
    }

    @Test func addTargetsTheLatestPinnedListAndOtherwiseMyDay() {
        let older = UUID()
        let newer = UUID()
        let running: [(scope: LockScreenScope, pinnedAt: Date)] = [
            (.list(older), today),
            (.list(newer), today.addingTimeInterval(10))
        ]

        #expect(lockScreenAddDestination(running: []) == .myDay)
        #expect(lockScreenAddDestination(running: running) == .list(newer))
        #expect(lockScreenAddDestination(running: [(.list(older), today), (.myDay, today)]) == .myDay)
    }

    @Test func struckThroughCircleDoesNotReopen() {
        #expect(lockScreenWriteCompletion(isCompleted: false) == true)
        #expect(lockScreenWriteCompletion(isCompleted: true) == nil)
    }

    @Test func pinErrorPrefersADisabledSystemOverAnEmptyList() {
        #expect(lockScreenPinError(activitiesEnabled: false, state: .ended) == .disabled)
        #expect(lockScreenPinError(activitiesEnabled: true, state: .ended) == .empty)
        #expect(lockScreenPinError(activitiesEnabled: true, state: .showing(rows: [row("Milk")], openCount: 1)) == nil)
    }

    @Test func contentCarriesTheWaitingCountAndTheAppearance() {
        let card = LockScreenCardState.showing(rows: [row("Milk")], openCount: 8)

        let content = lockScreenContent(name: "My Day", state: card, appearance: .transparent)

        #expect(content?.name == "My Day")
        #expect(content?.openCount == 8)
        #expect(content?.rows == [row("Milk")])
        #expect(content?.appearance == .transparent)
        #expect(lockScreenContent(name: "My Day", state: .ended, appearance: .standard) == nil)
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
            notes: nil,
            source: .local,
            sourceId: "test-source",
            editable: true
        )
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var today: Date {
        calendar.date(from: DateComponents(timeZone: TimeZone(secondsFromGMT: 0), year: 2026, month: 11, day: 20))!
    }

    private func source(
        _ title: String,
        due: Date? = nil,
        list: UUID? = nil,
        completed: Bool = false,
        createdHour: Int? = nil
    ) -> LockScreenSourceTask {
        let createdAt: Date
        if let createdHour {
            createdAt = calendar.date(bySettingHour: createdHour, minute: 0, second: 0, of: today)!
        } else {
            createdAt = today
        }
        return LockScreenSourceTask(
            id: stableID(for: title),
            title: title,
            completed: completed,
            dueDate: due,
            listId: list,
            createdAt: createdAt
        )
    }

    private func row(_ title: String, completed: Bool = false) -> LockScreenTaskRow {
        LockScreenTaskRow(id: stableID(for: title), title: title, completed: completed)
    }

    private func stableID(for title: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        for (index, byte) in title.utf8.enumerated() {
            bytes[index % 16] &+= byte &+ UInt8(index)
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

}
