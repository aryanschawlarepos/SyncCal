//
//  CalendarsSheet.swift
//  Cadence
//

import EventKit
import SwiftUI

/// Lets the user toggle which connected calendars are visible, grouped by account source
/// (iCloud / Apple, Google, etc.) so the multi-account connection is visible and controllable.
struct CalendarsSheet: View {
    let store: CalendarStore
    @Environment(\.dismiss) private var dismiss

    private var grouped: [(source: String, calendars: [EKCalendar])] {
        Dictionary(grouping: store.calendars, by: { $0.source.title })
            .map { (source: $0.key, calendars: $0.value) }
            .sorted { $0.source.localizedCaseInsensitiveCompare($1.source) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    ForEach(grouped, id: \.source) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.source.uppercased())
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                                .padding(.leading, 4)

                            VStack(spacing: 0) {
                                ForEach(Array(group.calendars.enumerated()), id: \.element.calendarIdentifier) { index, cal in
                                    row(for: cal)
                                    if index < group.calendars.count - 1 {
                                        Divider().overlay(Theme.stroke).padding(.leading, 44)
                                    }
                                }
                            }
                            .background(Theme.surface, in: .rect(cornerRadius: 16))
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Calendars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func row(for cal: EKCalendar) -> some View {
        let isVisible = !store.hiddenCalendarIDs.contains(cal.calendarIdentifier)
        return Button {
            toggle(cal)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: hex(cal.cgColor)))
                    .frame(width: 14, height: 14)
                Text(cal.title)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: isVisible ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isVisible ? Theme.accent : Theme.textTertiary)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ cal: EKCalendar) {
        if store.hiddenCalendarIDs.contains(cal.calendarIdentifier) {
            store.hiddenCalendarIDs.remove(cal.calendarIdentifier)
        } else {
            store.hiddenCalendarIDs.insert(cal.calendarIdentifier)
        }
        store.reload()
    }

    private func hex(_ cgColor: CGColor?) -> UInt {
        guard let components = cgColor?.components, components.count >= 3 else { return 0xF5B841 }
        let r = UInt(max(0, min(1, components[0])) * 255)
        let g = UInt(max(0, min(1, components[1])) * 255)
        let b = UInt(max(0, min(1, components[2])) * 255)
        return (r << 16) | (g << 8) | b
    }
}
