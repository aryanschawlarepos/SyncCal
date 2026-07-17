//
//  PerformanceSnapshots.swift
//  Cadence
//

import Foundation

enum CachedDateFormatters {
    static let eventTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    static let hour: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter
    }()

    static let dayWithWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    static let monthName: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }()

    static let shortMonthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

extension TaskPriority {
    var performanceRank: Int {
        switch self {
        case .none: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }
}

struct PlannerHourSection: Identifiable {
    let hour: Date
    let label: String
    let events: [EventItem]

    var id: Date { hour }
}

struct PlannerDaySnapshot {
    let today: Date
    let todayLabel: String
    let dayEvents: [EventItem]
    let allDayEvents: [EventItem]
    let timedEvents: [EventItem]
    let dueTodayTasks: [CadenceTask]
    let hourSections: [PlannerHourSection]
    let focusItemCount: Int

    init(events: [EventItem], tasks: [CadenceTask], today: Date, calendar: Calendar = .current) {
        self.today = today
        todayLabel = CachedDateFormatters.dayWithWeekday.string(from: today)

        let dayEnd = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        dayEvents = events
            .filter { $0.startDate < dayEnd && $0.endDate >= today }
            .sorted { $0.startDate < $1.startDate }
        allDayEvents = dayEvents.filter(\.isAllDay)
        timedEvents = dayEvents.filter { !$0.isAllDay }
        dueTodayTasks = tasks
            .filter { task in
                guard let dueDate = task.dueDate else { return false }
                return !task.completed && calendar.isDate(dueDate, inSameDayAs: today)
            }
            .sorted { lhs, rhs in
                if lhs.priorityRawValue == rhs.priorityRawValue {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.priority.performanceRank > rhs.priority.performanceRank
            }
        focusItemCount = allDayEvents.count + dueTodayTasks.count

        let bounds = PlannerTimeline.bounds(for: dayEvents, day: today, calendar: calendar)
        let start = calendar.dateInterval(of: .hour, for: bounds.lowerBound)?.start ?? bounds.lowerBound
        var hours: [Date] = []
        var current = start
        while current < bounds.upperBound {
            hours.append(current)
            guard let next = calendar.date(byAdding: .hour, value: 1, to: current) else { break }
            current = next
        }

        let groupedEvents = Dictionary(grouping: timedEvents) { event in
            calendar.dateInterval(of: .hour, for: event.startDate)?.start ?? event.startDate
        }
        hourSections = hours.map { hour in
            PlannerHourSection(
                hour: hour,
                label: CachedDateFormatters.hour.string(from: hour),
                events: groupedEvents[hour, default: []]
            )
        }
    }
}

struct TaskDashboardSummary {
    let openCount: Int
    let completedCount: Int
    let smartCounts: [TaskSmartList: Int]
    let openCountsByListId: [UUID: Int]

    init(tasks: [CadenceTask], today: Date, calendar: Calendar = .current) {
        var openCount = 0
        var completedCount = 0
        var smartCounts = Dictionary(uniqueKeysWithValues: TaskSmartList.allCases.map { ($0, 0) })
        var openCountsByListId: [UUID: Int] = [:]

        for task in tasks {
            if task.completed {
                completedCount += 1
                smartCounts[.completed, default: 0] += 1
                continue
            }

            openCount += 1
            smartCounts[.all, default: 0] += 1
            if let listId = task.listId {
                openCountsByListId[listId, default: 0] += 1
            }
            guard let dueDate = task.dueDate else { continue }
            if calendar.isDate(dueDate, inSameDayAs: today) {
                smartCounts[.myDay, default: 0] += 1
            }
            if dueDate >= today {
                smartCounts[.upcoming, default: 0] += 1
            }
        }

        self.openCount = openCount
        self.completedCount = completedCount
        self.smartCounts = smartCounts
        self.openCountsByListId = openCountsByListId
    }
}

struct TaskListSnapshot {
    let tasks: [CadenceTask]

    init(scope: TaskListScope, tasks: [CadenceTask], today: Date, calendar: Calendar = .current) {
        self.tasks = tasks
            .filter { task in
                switch scope {
                case .smart(let smartList):
                    switch smartList {
                    case .myDay:
                        guard let dueDate = task.dueDate else { return false }
                        return !task.completed && calendar.isDate(dueDate, inSameDayAs: today)
                    case .upcoming:
                        guard let dueDate = task.dueDate else { return false }
                        return !task.completed && dueDate >= today
                    case .all:
                        return !task.completed
                    case .completed:
                        return task.completed
                    }
                case .custom(let listId, _):
                    return !task.completed && task.listId == listId
                }
            }
            .sorted { lhs, rhs in
                switch (lhs.dueDate, rhs.dueDate) {
                case let (lhsDate?, rhsDate?):
                    if lhsDate == rhsDate { return lhs.createdAt > rhs.createdAt }
                    return lhsDate < rhsDate
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.createdAt > rhs.createdAt
                }
            }
    }
}
