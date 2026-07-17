//
//  UpcomingView.swift
//  Cadence
//

import SwiftData
import SwiftUI

struct UpcomingView: View {
    let store: CalendarStore
    let notifications: NotificationManager

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \CadenceTask.createdAt, order: .reverse) private var tasks: [CadenceTask]
    @Query(sort: \TaskList.sortIndex) private var lists: [TaskList]

    @State private var showEventEditor = false
    @State private var showTaskEditor = false
    @State private var eventToInspect: EventItem?
    @State private var eventToEdit: EventItem?
    @State private var eventPendingDelete: EventItem?
    @State private var taskToInspect: CadenceTask?
    @State private var taskToEdit: CadenceTask?
    @State private var taskPendingDelete: CadenceTask?
    @State private var deletionErrorMessage: String?

    private let calendar = Calendar.current

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var snapshot: UpcomingSnapshot {
        UpcomingSnapshot(events: store.upcomingEvents, tasks: tasks, today: today, calendar: calendar)
    }

    var body: some View {
        let snapshot = snapshot

        ZStack(alignment: .bottomTrailing) {
            Theme.background.ignoresSafeArea()
            Theme.glow.ignoresSafeArea()

            VStack(spacing: 0) {
                header(snapshot: snapshot)
                content(snapshot: snapshot)
            }

            addButton
        }
        .accessibilityIdentifier("upcoming-screen")
        .sheet(isPresented: $showEventEditor) {
            EventEditorView(store: store, notifications: notifications, initialDate: today)
        }
        .sheet(isPresented: $showTaskEditor) {
            TaskEditorView(task: nil, preferredListId: lists.first?.id, preferredDueDate: today)
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
        .sheet(item: $taskToInspect) { task in
            TaskDetailView(task: task)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $taskToEdit) { task in
            TaskEditorView(task: task, preferredListId: task.listId)
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
                Text("This removes \"\(eventPendingDelete.title)\" from \(eventPendingDelete.calendarTitle).")
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
                Text("This removes \"\(taskPendingDelete.title)\" immediately.")
            }
        }
        .alert("Couldn’t delete item", isPresented: deletionErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionErrorMessage ?? "The item could not be deleted.")
        }
        .task {
            if store.calendars.isEmpty {
                store.loadCalendars()
            }
            store.reloadUpcomingEvents()
        }
    }

    private func header(snapshot: UpcomingSnapshot) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Upcoming")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(snapshot.summaryLabel)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
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
                        createEvent()
                    } label: {
                        Label("Event", systemImage: "calendar.badge.plus")
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

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    store.reloadUpcomingEvents()
                } label: {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 34, height: 34)
                        .contentShape(Circle())
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.9))
                .accessibilityLabel("Refresh upcoming")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func content(snapshot: UpcomingSnapshot) -> some View {
        Group {
            if snapshot.sections.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
                        ForEach(snapshot.sections) { section in
                            Section {
                                VStack(spacing: 10) {
                                    ForEach(section.items) { item in
                                        upcomingRow(item)
                                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                                    }
                                }
                                .padding(.horizontal, 16)
                            } header: {
                                UpcomingDateHeader(section: section)
                                    .padding(.horizontal, 16)
                                    .background(Theme.background.opacity(0.96))
                            }
                        }
                    }
                    .padding(.bottom, 112)
                }
                .animation(reduceMotion ? .easeInOut(duration: 0.16) : .spring(response: 0.28, dampingFraction: 0.9), value: snapshot.itemIDs)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.coolAccent.opacity(0.14))
                    .frame(width: 84, height: 84)

                Image(systemName: "checkmark.seal")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.coolAccent)
            }

            Text("You're all caught up.")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            Text("No upcoming events or tasks.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 280)

            HStack(spacing: 10) {
                Button {
                    createTask()
                } label: {
                    Label("Add Task", systemImage: "checkmark.circle")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.accentGradient, in: .capsule)
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.94))

                Button {
                    createEvent()
                } label: {
                    Label("Create Event", systemImage: "calendar.badge.plus")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.accentSoft, in: .capsule)
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.94))
            }
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }

    private var addButton: some View {
        Menu {
            Button {
                createTask()
            } label: {
                Label("Task", systemImage: "checkmark.circle")
            }

            Button {
                createEvent()
            } label: {
                Label("Event", systemImage: "calendar.badge.plus")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 62, height: 62)
                .background(Theme.accentGradient, in: .circle)
                .shadow(color: Theme.accent.opacity(0.45), radius: 18, y: 8)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Add upcoming item")
        .padding(.trailing, 22)
        .padding(.bottom, 28)
    }

    private func upcomingRow(_ item: UpcomingItem) -> some View {
        Button {
            open(item)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 4) {
                    Text(item.timeLabel)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(item.tint)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.78)
                }
                .frame(width: 58)
                .padding(.top, 2)

                RoundedRectangle(cornerRadius: 3)
                    .fill(item.tint)
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(item.detailLabel)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)

                    Label(item.sourceLabel, systemImage: item.sourceSymbolName)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(item.tint)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(item.tint.opacity(0.12), in: .capsule)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.strokeSoft, lineWidth: 1)
            )
            .shadow(color: Theme.shadow, radius: 8, y: 5)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.985))
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if case .task(let task) = item {
                Button {
                    toggle(task)
                } label: {
                    Label(task.completed ? "Reopen" : "Complete", systemImage: task.completed ? "arrow.uturn.left" : "checkmark")
                }
                .tint(task.completed ? .orange : .green)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                requestDelete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(!item.canDelete)
        }
        .contextMenu {
            Button {
                edit(item)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .disabled(!item.canEdit)

            if case .task(let task) = item {
                Button {
                    toggle(task)
                } label: {
                    Label(task.completed ? "Mark Incomplete" : "Complete", systemImage: task.completed ? "circle" : "checkmark.circle")
                }
            }

            Button(role: .destructive) {
                requestDelete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(!item.canDelete)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.detailLabel), \(item.sourceLabel)")
    }

    private func open(_ item: UpcomingItem) {
        switch item {
        case .event(let event):
            eventToInspect = event
        case .task(let task):
            taskToInspect = task
        }
    }

    private func edit(_ item: UpcomingItem) {
        switch item {
        case .event(let event):
            guard event.editable else { return }
            eventToEdit = event
        case .task(let task):
            taskToEdit = task
        }
    }

    private func requestDelete(_ item: UpcomingItem) {
        switch item {
        case .event(let event):
            guard event.editable else { return }
            eventPendingDelete = event
        case .task(let task):
            taskPendingDelete = task
        }
    }

    private func createTask() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showTaskEditor = true
    }

    private func createEvent() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showEventEditor = true
    }

    private func toggle(_ task: CadenceTask) {
        task.completed.toggle()
        task.updatedAt = Date()
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(task.completed ? .success : .warning)
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
}

private struct UpcomingDateHeader: View {
    let section: UpcomingSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(section.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .textCase(.uppercase)

                Spacer()

                Text(section.subtitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }

            Rectangle()
                .fill(Theme.strokeSoft)
                .frame(height: 1)
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
    }
}

private struct UpcomingSnapshot {
    let sections: [UpcomingSection]
    let summaryLabel: String

    var itemIDs: [String] {
        sections.flatMap { $0.items.map(\.id) }
    }

    init(events: [EventItem], tasks: [CadenceTask], today: Date, calendar: Calendar = .current) {
        let now = Date()
        let taskItems = tasks.compactMap { task -> UpcomingItem? in
            guard !task.completed, let dueDate = task.dueDate else { return nil }
            guard dueDate >= today else { return nil }
            return .task(task)
        }
        let eventItems = events.compactMap { event -> UpcomingItem? in
            guard event.endDate >= now else { return nil }
            return .event(event)
        }
        let items = (eventItems + taskItems).sorted { lhs, rhs in
            if lhs.sortDate == rhs.sortDate {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.sortDate < rhs.sortDate
        }

        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.sortDate)
        }
        sections = grouped.keys.sorted().map { day in
            UpcomingSection(
                date: day,
                title: Self.title(for: day, today: today, calendar: calendar),
                subtitle: Self.subtitle(for: day),
                items: grouped[day, default: []]
            )
        }

        let itemCount = items.count
        summaryLabel = itemCount == 1 ? "1 item ahead" : "\(itemCount) items ahead"
    }

    private static func title(for date: Date, today: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: today) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return CachedDateFormatters.dayWithWeekday.string(from: date)
    }

    private static func subtitle(for date: Date) -> String {
        CachedDateFormatters.shortMonthDay.string(from: date)
    }
}

private struct UpcomingSection: Identifiable {
    let date: Date
    let title: String
    let subtitle: String
    let items: [UpcomingItem]

    var id: Date { date }
}

private enum UpcomingItem: Identifiable {
    case event(EventItem)
    case task(CadenceTask)

    var id: String {
        switch self {
        case .event(let event): return "event-\(event.id)"
        case .task(let task): return "task-\(task.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .event(let event): return event.title
        case .task(let task): return task.title
        }
    }

    var sortDate: Date {
        switch self {
        case .event(let event): return event.startDate
        case .task(let task): return task.dueDate ?? task.createdAt
        }
    }

    var timeLabel: String {
        switch self {
        case .event(let event):
            return event.isAllDay ? "All-day" : CachedDateFormatters.eventTime.string(from: event.startDate)
        case .task(let task):
            guard let dueDate = task.dueDate else { return "Task" }
            if Calendar.current.isDateInToday(dueDate) { return "Today" }
            if Calendar.current.isDateInTomorrow(dueDate) { return "Tomorrow" }
            return CachedDateFormatters.shortMonthDay.string(from: dueDate)
        }
    }

    var detailLabel: String {
        switch self {
        case .event(let event):
            return event.rangeLabel
        case .task(let task):
            guard let dueDate = task.dueDate else { return "Task" }
            if Calendar.current.isDateInToday(dueDate) { return "Due today" }
            if Calendar.current.isDateInTomorrow(dueDate) { return "Due tomorrow" }
            return "Due \(CachedDateFormatters.shortMonthDay.string(from: dueDate))"
        }
    }

    var sourceLabel: String {
        switch self {
        case .event(let event):
            return event.source == .local ? "Cadence Event" : event.source.label
        case .task:
            return "Task"
        }
    }

    var sourceSymbolName: String {
        switch self {
        case .event(let event):
            switch event.source {
            case .local: return "calendar.badge.clock"
            case .apple: return "apple.logo"
            case .google: return "g.circle"
            }
        case .task:
            return "checkmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .event(let event): return event.tint
        case .task: return Theme.coolAccent
        }
    }

    var canEdit: Bool {
        switch self {
        case .event(let event): return event.editable
        case .task: return true
        }
    }

    var canDelete: Bool {
        canEdit
    }
}
