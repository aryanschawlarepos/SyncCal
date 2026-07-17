//
//  CalendarHomeView.swift
//  Cadence
//

import SwiftUI

/// Primary screen: animated month header, month grid, and the selected day's agenda.
struct CalendarHomeView: View {
    let store: CalendarStore
    let notifications: NotificationManager

    @State private var showEditor = false
    @State private var showCalendars = false
    @State private var eventToInspect: EventItem?
    @State private var eventToEdit: EventItem?
    @State private var eventPendingDelete: EventItem?
    @State private var deletionErrorMessage: String?

    private let calendar = Calendar.current

    private var yearTitle: String {
        String(calendar.component(.year, from: store.displayedMonth))
    }

    var body: some View {
        let monthTitle = CachedDateFormatters.monthName.string(from: store.displayedMonth)
        let eventCounts = store.eventCounts()
        let selectedDayEvents = store.events(on: store.selectedDate)

        ZStack(alignment: .bottomTrailing) {
            Theme.background.ignoresSafeArea()
            Theme.glow.ignoresSafeArea()

            VStack(spacing: 0) {
                header(monthTitle: monthTitle)
                MonthGridView(
                    month: store.displayedMonth,
                    selectedDate: store.selectedDate,
                    counts: eventCounts,
                    onSelect: select
                )
                .padding(.horizontal, 16)
                .padding(.top, 4)

                agendaHeader
                agendaList(events: selectedDayEvents)
            }

            addButton
        }
        .sheet(isPresented: $showEditor) {
            EventEditorView(store: store, notifications: notifications, initialDate: store.selectedDate)
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
        .sheet(isPresented: $showCalendars) {
            CalendarsSheet(store: store)
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
        .alert("Couldn’t delete event", isPresented: deletionErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionErrorMessage ?? "The event could not be deleted.")
        }
        .task {
            store.reload()
        }
    }

    // MARK: - Header

    private func header(monthTitle: String) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: -2) {
                Text(monthTitle)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                Text(yearTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }

            Spacer()

            HStack(spacing: 10) {
                circleButton(icon: "line.3.horizontal.decrease") { showCalendars = true }
                circleButton(icon: "chevron.left") { changeMonth(by: -1) }
                circleButton(icon: "chevron.right") { changeMonth(by: 1) }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var agendaHeader: some View {
        HStack {
            Text(selectedDayLabel)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if !calendar.isDateInToday(store.selectedDate) {
                Button {
                    select(Date())
                    changeMonthToSelection()
                } label: {
                    Text("Today")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.accentSoft, in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private func agendaList(events dayEvents: [EventItem]) -> some View {
        Group {
            if dayEvents.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(dayEvents) { event in
                            EventRow(event: event)
                                .onTapGesture { eventToInspect = event }
                                .contextMenu {
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
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 120)
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.selectedDate)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.accentSoft)
                    .frame(width: 82, height: 82)

                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.accentGradient)
            }

            Text("Nothing planned")
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            Text("A clear day. Add an event, or keep the space open.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 260)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showEditor = true
            } label: {
                Label("Add event", systemImage: "plus")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Theme.accentGradient, in: .capsule)
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.94))
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Add button

    private var addButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showEditor = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 62, height: 62)
                .background(Theme.accentGradient, in: .circle)
                .shadow(color: Theme.accent.opacity(0.45), radius: 18, y: 8)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Add event")
        .padding(.trailing, 22)
        .padding(.bottom, 28)
    }

    // MARK: - Helpers

    private var selectedDayLabel: String {
        if calendar.isDateInToday(store.selectedDate) { return "Today" }
        if calendar.isDateInTomorrow(store.selectedDate) { return "Tomorrow" }
        return CachedDateFormatters.dayWithWeekday.string(from: store.selectedDate)
    }

    private func circleButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 40, height: 40)
                .background(Theme.surface, in: .circle)
                .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.92))
    }

    private func select(_ date: Date) {
        UISelectionFeedbackGenerator().selectionChanged()
        store.selectedDate = calendar.startOfDay(for: date)
    }

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: store.displayedMonth) else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            store.displayedMonth = newMonth.startOfMonth
        }
        store.reload()
    }

    private func changeMonthToSelection() {
        let target = store.selectedDate.startOfMonth
        if !calendar.isDate(target, equalTo: store.displayedMonth, toGranularity: .month) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                store.displayedMonth = target
            }
            store.reload()
        }
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
