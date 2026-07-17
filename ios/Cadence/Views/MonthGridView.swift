//
//  MonthGridView.swift
//  Cadence
//

import SwiftUI

/// The tappable month grid with event-density dots and animated day selection.
struct MonthGridView: View {
    let month: Date
    let selectedDate: Date
    let counts: [Date: Int]
    let onSelect: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                ForEach(Array(calendar.orderedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol.uppercased())
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(month.monthGridDays, id: \.self) { day in
                    DayCell(
                        day: day,
                        isInMonth: calendar.isDate(day, equalTo: month, toGranularity: .month),
                        isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(day),
                        eventCount: counts[calendar.startOfDay(for: day)] ?? 0,
                        onTap: { onSelect(day) }
                    )
                }
            }
        }
    }
}

private struct DayCell: View {
    let day: Date
    let isInMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let eventCount: Int
    let onTap: () -> Void

    private var dayNumber: String {
        String(Calendar.current.component(.day, from: day))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                Text(dayNumber)
                    .font(.system(size: 16, weight: isToday ? .bold : .medium, design: .rounded))
                    .foregroundStyle(numberColor)
                    .frame(width: 34, height: 34)
                    .background {
                        if isSelected {
                            Circle().fill(Theme.accentGradient)
                                .shadow(color: Theme.accent.opacity(0.4), radius: 8, y: 2)
                        } else if isToday {
                            Circle().stroke(Theme.accent.opacity(0.6), lineWidth: 1.5)
                        }
                    }

                HStack(spacing: 3) {
                    ForEach(0 ..< min(eventCount, 3), id: \.self) { _ in
                        Circle()
                            .fill(isSelected ? Theme.accent : Theme.textSecondary)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
                .opacity(eventCount > 0 ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isInMonth ? 1 : 0.28)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private var numberColor: Color {
        if isSelected { return Theme.onAccent }
        if isToday { return Theme.accent }
        return Theme.textPrimary
    }
}
