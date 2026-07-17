//
//  EventDetailView.swift
//  Cadence
//

import SwiftUI

struct EventDetailView: View {
    let event: EventItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    detailsCard

                    if event.editable {
                        Button(role: .destructive) {
                            dismiss()
                            onDelete()
                        } label: {
                            Label("Delete Event", systemImage: "trash")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }

                if event.editable {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Edit") {
                            Task { @MainActor in
                                dismiss()
                                try? await Task.sleep(nanoseconds: 250_000_000)
                                onEdit()
                            }
                        }
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(event.tint)
                    .frame(width: 5, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(event.source.label)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(event.tint)
                }
            }

            Label(event.rangeLabel, systemImage: event.isAllDay ? "sun.max.fill" : "clock")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceGradient, in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.strokeSoft, lineWidth: 1)
        )
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailRow(icon: "calendar.badge.clock", title: "Date", value: eventDateLabel)
            detailRow(icon: event.isAllDay ? "sun.max" : "clock", title: "Time", value: event.rangeLabel)
            detailRow(icon: "calendar", title: "Calendar", value: event.calendarTitle)
            detailRow(icon: "rectangle.connected.to.line.below", title: "Source", value: event.sourceTitle)

            if let location = event.location, !location.isEmpty {
                detailRow(icon: "mappin.and.ellipse", title: "Location", value: location)
            }

            if let notes = event.notes, !notes.isEmpty {
                detailRow(icon: "text.alignleft", title: "Notes", value: notes)
            }

            if !event.editable {
                Label("Changes to this event must be made in the original calendar.", systemImage: "lock.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.strokeSoft, lineWidth: 1)
        )
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .textCase(.uppercase)
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var eventDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: event.startDate)
    }
}
