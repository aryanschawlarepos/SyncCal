//
//  EventRow.swift
//  Cadence
//

import SwiftUI

/// A single event card in the agenda list.
struct EventRow: View {
    let event: EventItem

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3)
                .fill(event.tint)
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Label(event.rangeLabel, systemImage: event.isAllDay ? "sun.max.fill" : "clock")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .labelStyle(.titleAndIcon)
                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 5) {
                    Circle().fill(event.tint).frame(width: 6, height: 6)
                    Text(event.calendarTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.top, 1)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(minHeight: 76)
        .background(Theme.surface, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.stroke, lineWidth: 1)
        )
        .shadow(color: Theme.shadow, radius: 10, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title), \(event.rangeLabel), \(event.calendarTitle)")
    }
}
