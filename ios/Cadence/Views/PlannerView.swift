//
//  PlannerView.swift
//  Cadence
//

import SwiftData
import SwiftUI

/// Today's agenda shown as a dynamic full-screen timeline with calendar events and due-today tasks.
struct PlannerView: View {
    let store: CalendarStore
    let notifications: NotificationManager

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \CadenceTask.createdAt, order: .reverse) private var tasks: [CadenceTask]
    @Query(sort: \TaskList.sortIndex) private var lists: [TaskList]

    @State private var showEditor = false
    @State private var showTaskEditor = false
    @State private var selectedEventStartDate: Date?
    @State private var taskToEdit: CadenceTask?
    @State private var taskToDirectEdit: CadenceTask?
    @State private var eventToInspect: EventItem?
    @State private var eventToEdit: EventItem?
    @State private var eventPendingDelete: EventItem?
    @State private var taskPendingDelete: CadenceTask?
    @State private var deletionErrorMessage: String?

    private let calendar = Calendar.current
    private let minimumHourHeight: CGFloat = 42
    private let maximumHourHeight: CGFloat = 88

    private var today: Date { calendar.startOfDay(for: Date()) }

    private var dayEvents: [EventItem] {
        store.events(on: today).sorted { $0.startDate < $1.startDate }
    }

    private var allDayEvents: [EventItem] {
        dayEvents.filter(\.isAllDay)
    }

    private var timedEvents: [EventItem] {
        dayEvents.filter { !$0.isAllDay }
    }

    private var dueTodayTasks: [CadenceTask] {
        tasks
            .filter { task in
                guard let dueDate = task.dueDate else { return false }
                return !task.completed && calendar.isDate(dueDate, inSameDayAs: today)
            }
            .sorted { lhs, rhs in
                if lhs.priorityRawValue == rhs.priorityRawValue {
                    return lhs.createdAt > rhs.createdAt
                }
                return priorityRank(lhs.priority) > priorityRank(rhs.priority)
            }
    }

    private var focusItemCount: Int {
        allDayEvents.count + dueTodayTasks.count
    }

    private var timelineBounds: ClosedRange<Date> {
        PlannerTimeline.bounds(for: dayEvents, day: today, calendar: calendar)
    }

    private var hourStarts: [Date] {
        let start = calendar.dateInterval(of: .hour, for: timelineBounds.lowerBound)?.start
            ?? timelineBounds.lowerBound
        var result: [Date] = []
        var current = start
        while current < timelineBounds.upperBound {
            result.append(current)
            guard let next = calendar.date(byAdding: .hour, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Theme.glow.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                GeometryReader { proxy in
                    plannerBody(availableHeight: proxy.size.height)
                }
            }
        }
        .accessibilityIdentifier("planner-screen")
        .sheet(isPresented: $showEditor) {
            EventEditorView(
                store: store,
                notifications: notifications,
                initialDate: today,
                initialStartDate: selectedEventStartDate
            )
        }
        .sheet(isPresented: $showTaskEditor) {
            TaskEditorView(task: nil, preferredListId: lists.first?.id, preferredDueDate: today)
        }
        .sheet(item: $taskToEdit) { task in
            TaskDetailView(task: task)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $taskToDirectEdit) { task in
            TaskEditorView(task: task, preferredListId: task.listId)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $eventToInspect) { event in
            EventDetailView(
                event: event,
                onEdit: { eventToEdit = event },
                onDelete: { eventPendingDelete = event }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $eventToEdit) { event in
            EventEditorView(
                event: event,
                store: store,
                notifications: notifications,
                initialDate: event.startDate
            )
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Delete Event?", isPresented: eventDeleteDialogBinding) {
            if let eventPendingDelete {
                Button("Delete Event", role: .destructive) {
                    delete(eventPendingDelete)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let eventPendingDelete {
                Text("This removes “\(eventPendingDelete.title)” from \(eventPendingDelete.calendarTitle).")
            }
        }
        .confirmationDialog("Delete Task?", isPresented: taskDeleteDialogBinding) {
            if let taskPendingDelete {
                Button("Delete Task", role: .destructive) {
                    delete(taskPendingDelete)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let taskPendingDelete {
                Text("This removes “\(taskPendingDelete.title)” immediately.")
            }
        }
        .alert("Couldn’t delete item", isPresented: deletionErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionErrorMessage ?? "The item could not be deleted.")
        }
        .task {
            store.reloadEvents(for: today)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Planner")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(todayLabel)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }

            Spacer()

            HStack(spacing: 10) {
                Menu {
                    Button {
                        createTask()
                    } label: {
                        Label("Task", systemImage: "checkmark.circle")
                    }

                    Button {
                        createEvent(at: nil)
                    } label: {
                        Label("Event", systemImage: "calendar.badge.plus")
                    }

                    Button {
                        createQuickTask()
                    } label: {
                        Label("Quick Task", systemImage: "bolt.fill")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 34, height: 34)
                        .contentShape(Circle())
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.9))
                .accessibilityLabel("Create")

                Menu {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        store.reloadEvents(for: today)
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 34, height: 34)
                        .contentShape(Circle())
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.9))
                .accessibilityLabel("More")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func plannerBody(availableHeight: CGFloat) -> some View {
        let hourHeight = dynamicHourHeight(availableHeight: availableHeight)
        let focusHeight = estimatedFocusHeight
        let contentHeight = focusHeight + (CGFloat(hourStarts.count) * hourHeight) + 12
        let shouldScroll = contentHeight > availableHeight

        return Group {
            if shouldScroll {
                ScrollView {
                    plannerContent(hourHeight: hourHeight)
                        .padding(.bottom, 8)
                }
            } else {
                plannerContent(hourHeight: hourHeight)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 16)
        .animation(reduceMotion ? .easeInOut(duration: 0.18) : .spring(response: 0.38, dampingFraction: 0.86), value: hourHeight)
        .animation(reduceMotion ? .easeInOut(duration: 0.18) : .spring(response: 0.34, dampingFraction: 0.84), value: dayEvents.map(\.id))
        .animation(reduceMotion ? .easeInOut(duration: 0.18) : .spring(response: 0.34, dampingFraction: 0.84), value: dueTodayTasks.map(\.id))
    }

    private func plannerContent(hourHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if focusItemCount == 0 && timedEvents.isEmpty {
                openDayBanner
            } else if focusItemCount > 0 {
                focusSection
            }

            timeline(hourHeight: hourHeight)
        }
    }

    private var openDayBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.coolAccent)
                .frame(width: 38, height: 38)
                .background(Theme.coolAccent.opacity(0.14), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text("Open day")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text("Your timeline is clear. The full-day canvas is ready.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(Theme.surface.opacity(0.74), in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.strokeSoft, lineWidth: 1)
        )
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FOCUS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .tracking(1)

            ForEach(allDayEvents) { event in
                plannerEventCard(event, compact: true)
                    .onTapGesture { eventToInspect = event }
                    .contextMenu { eventContextMenu(for: event) }
            }

            ForEach(dueTodayTasks) { task in
                plannerTaskCard(task)
                    .contextMenu { taskContextMenu(for: task) }
            }
        }
    }

    private func timeline(hourHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(hourStarts, id: \.self) { hour in
                hourRow(hour, height: hourHeight)
            }
        }
    }

    private func hourRow(_ hour: Date, height: CGFloat) -> some View {
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: hour) ?? hour
        let events = timedEvents.filter { event in
            event.startDate >= hour && event.startDate < nextHour
        }
        let compact = height < 54

        return HStack(alignment: .top, spacing: 12) {
            Text(hourLabel(hour))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 58, alignment: .leading)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: compact ? 5 : 8) {
                Rectangle()
                    .fill(Theme.stroke)
                    .frame(height: 1)

                ForEach(events) { event in
                    plannerEventCard(event, compact: compact)
                        .onTapGesture { eventToInspect = event }
                        .contextMenu { eventContextMenu(for: event) }
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }

                emptyHourTapTarget(hour: hour, height: height, eventCount: events.count)
            }
            .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
        }
        .frame(minHeight: height, alignment: .top)
    }

    private func emptyHourTapTarget(hour: Date, height: CGFloat, eventCount: Int) -> some View {
        Button {
            createEvent(at: hour)
        } label: {
            Rectangle()
                .fill(.clear)
                .frame(maxWidth: .infinity)
                .frame(height: emptyTapHeight(for: height, eventCount: eventCount))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create event at \(hourLabel(hour))")
    }

    private func emptyTapHeight(for hourHeight: CGFloat, eventCount: Int) -> CGFloat {
        let estimatedEventHeight: CGFloat = hourHeight < 54 ? 38 : 62
        return max(18, hourHeight - 9 - (CGFloat(eventCount) * estimatedEventHeight))
    }

    private func plannerEventCard(_ event: EventItem, compact: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(event.tint)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: compact ? 13 : 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(event.source.label)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(event.tint)
                        .lineLimit(1)
                }

                if !compact {
                    Text(event.rangeLabel)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)

                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(compact ? 9 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(event.tint.opacity(0.13), in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(event.tint.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title), \(event.rangeLabel), \(event.source.label)")
    }

    private func plannerTaskCard(_ task: CadenceTask) -> some View {
        HStack(spacing: 10) {
            Button {
                toggle(task)
            } label: {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(task.completed ? Theme.coolAccent : Theme.textTertiary)
                    .symbolEffect(.bounce, value: task.completed)
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.86))

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Text("Task • Due today")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            if task.priority != .none {
                Image(systemName: task.priority.symbolName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(priorityColor(for: task))
            }
        }
        .padding(12)
        .background(Theme.coolAccent.opacity(0.12), in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.coolAccent.opacity(0.28), lineWidth: 1)
        )
        .onTapGesture { taskToEdit = task }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                toggle(task)
            } label: {
                Label("Complete", systemImage: "checkmark")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                taskPendingDelete = task
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func eventContextMenu(for event: EventItem) -> some View {
        Button {
            eventToInspect = event
        } label: {
            Label("Details", systemImage: "info.circle")
        }

        if event.editable {
            Button {
                eventToEdit = event
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                eventPendingDelete = event
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func taskContextMenu(for task: CadenceTask) -> some View {
        Button {
            taskToDirectEdit = task
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Button {
            toggle(task)
        } label: {
            Label("Complete", systemImage: "checkmark.circle")
        }

        Button(role: .destructive) {
            taskPendingDelete = task
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private var estimatedFocusHeight: CGFloat {
        guard focusItemCount > 0 || timedEvents.isEmpty else { return 0 }
        let bannerHeight: CGFloat = timedEvents.isEmpty && focusItemCount == 0 ? 72 : 0
        let sectionHeader: CGFloat = focusItemCount > 0 ? 24 : 0
        return bannerHeight + sectionHeader + CGFloat(focusItemCount) * 58
    }

    private func dynamicHourHeight(availableHeight: CGFloat) -> CGFloat {
        guard !hourStarts.isEmpty else { return maximumHourHeight }
        let reservedHeight = estimatedFocusHeight + 12
        let availableForTimeline = max(availableHeight - reservedHeight - 8, CGFloat(hourStarts.count) * minimumHourHeight)
        let proposedHeight = availableForTimeline / CGFloat(hourStarts.count)
        let eventPressure = CGFloat(max(timedEvents.count - 3, 0)) * 2
        return min(maximumHourHeight, max(minimumHourHeight, proposedHeight - eventPressure))
    }

    private func toggle(_ task: CadenceTask) {
        task.completed.toggle()
        task.updatedAt = Date()
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(task.completed ? .success : .warning)
    }

    private func createTask() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showTaskEditor = true
    }

    private func createEvent(at startDate: Date?) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        selectedEventStartDate = startDate
        showEditor = true
    }

    private func createQuickTask() {
        let task = CadenceTask(
            title: "New Task",
            dueDate: today,
            listId: lists.first?.id
        )
        modelContext.insert(task)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        taskToDirectEdit = task
    }

    private func delete(_ task: CadenceTask) {
        modelContext.delete(task)
        try? modelContext.save()
        taskPendingDelete = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func delete(_ event: EventItem) {
        do {
            try store.deleteEvent(id: event.id)
            eventPendingDelete = nil
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            deletionErrorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private var deletionErrorBinding: Binding<Bool> {
        Binding(
            get: { deletionErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    deletionErrorMessage = nil
                }
            }
        )
    }

    private var eventDeleteDialogBinding: Binding<Bool> {
        Binding(
            get: { eventPendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    eventPendingDelete = nil
                }
            }
        )
    }

    private var taskDeleteDialogBinding: Binding<Bool> {
        Binding(
            get: { taskPendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    taskPendingDelete = nil
                }
            }
        )
    }

    private func priorityRank(_ priority: TaskPriority) -> Int {
        switch priority {
        case .none: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }

    private func priorityColor(for task: CadenceTask) -> Color {
        switch task.priority {
        case .none: return Theme.textTertiary
        case .low: return Theme.coolAccent
        case .medium: return Theme.accent
        case .high: return .red
        }
    }

    private var todayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: today)
    }

    private func hourLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
    }
}
