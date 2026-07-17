//
//  TaskRow.swift
//  Cadence
//

import SwiftUI

struct TaskRow: View {
    let task: CadenceTask
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggle) {
                    Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(task.completed ? Theme.coolAccent : Theme.textTertiary)
                        .symbolEffect(.bounce, value: task.completed)
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.86))
                .accessibilityLabel(task.completed ? "Mark incomplete" : "Complete task")

                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(task.completed ? Theme.textSecondary : Theme.textPrimary)
                        .strikethrough(task.completed, color: Theme.textTertiary)
                        .lineLimit(2)

                    metadata
                }

                Spacer(minLength: 0)

                if task.priority != .none {
                    Image(systemName: task.priority.symbolName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(priorityColor)
                        .padding(7)
                        .background(priorityColor.opacity(0.13), in: .circle)
                }
            }
            .padding(14)
            .background(Theme.surface, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.strokeSoft, lineWidth: 1)
            )
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.985))
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onToggle()
            } label: {
                Label(task.completed ? "Reopen" : "Complete", systemImage: task.completed ? "arrow.uturn.left" : "checkmark")
            }
            .tint(task.completed ? .orange : .green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                onToggle()
            } label: {
                Label(task.completed ? "Mark Incomplete" : "Complete", systemImage: task.completed ? "circle" : "checkmark.circle")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var metadata: some View {
        HStack(spacing: 10) {
            if let dueDate = task.dueDate {
                Label(dueLabel(for: dueDate), systemImage: "calendar")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(dueDate < Calendar.current.startOfDay(for: Date()) && !task.completed ? .red : Theme.textSecondary)
                    .lineLimit(1)
            }

            if !task.notes.isEmpty {
                Label("Notes", systemImage: "text.alignleft")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .labelStyle(.titleAndIcon)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .none: return Theme.textTertiary
        case .low: return Theme.coolAccent
        case .medium: return Theme.accent
        case .high: return .red
        }
    }

    private var accessibilityLabel: String {
        var parts = [task.title]
        if task.completed { parts.append("completed") }
        if let dueDate = task.dueDate { parts.append("due \(dueLabel(for: dueDate))") }
        if task.priority != .none { parts.append("\(task.priority.label) priority") }
        return parts.joined(separator: ", ")
    }

    private func dueLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }

        return CachedDateFormatters.shortMonthDay.string(from: date)
    }
}
