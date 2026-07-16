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

    private let calendar = Calendar.current

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: store.displayedMonth)
    }

    private var yearTitle: String {
        String(calendar.component(.year, from: store.displayedMonth))
    }

    private var dayEvents: [EventItem] {
        store.events(on: store.selectedDate)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Theme.background.ignoresSafeArea()
            Theme.glow.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                MonthGridView(
                    month: store.displayedMonth,
                    selectedDate: store.selectedDate,
                    counts: store.eventCounts(),
                    onSelect: select
                )
                .padding(.horizontal, 16)
                .padding(.top, 4)

                agendaHeader
                agendaList
            }

            addButton
        }
        .sheet(isPresented: $showEditor) {
            EventEditorView(store: store, notifications: notifications, initialDate: store.selectedDate)
        }
        .sheet(isPresented: $showCalendars) {
            CalendarsSheet(store: store)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Header

    private var header: some View {
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

    private var agendaList: some View {
        Group {
            if dayEvents.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(dayEvents) { event in
                            EventRow(event: event)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deleteEvent(id: event.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
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
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent.opacity(0.8))
            Text("Nothing planned")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("Tap + to add something to this day.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Add button

    private var addButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showEditor = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.background)
                .frame(width: 62, height: 62)
                .background(Theme.accentGradient, in: .circle)
                .shadow(color: Theme.accent.opacity(0.45), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 22)
        .padding(.bottom, 28)
    }

    // MARK: - Helpers

    private var selectedDayLabel: String {
        if calendar.isDateInToday(store.selectedDate) { return "Today" }
        if calendar.isDateInTomorrow(store.selectedDate) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: store.selectedDate)
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
        .buttonStyle(.plain)
    }

    private func select(_ date: Date) {
        store.selectedDate = calendar.startOfDay(for: date)
    }

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: store.displayedMonth) else { return }
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
}
