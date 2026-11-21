//
//  CadenceTask.swift
//  Cadence
//

import Foundation
import SwiftData

enum TaskPriority: String, CaseIterable, Codable, Identifiable {
    case none
    case low
    case medium
    case high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var symbolName: String {
        switch self {
        case .none: return "minus"
        case .low: return "flag"
        case .medium: return "flag.fill"
        case .high: return "exclamationmark.2"
        }
    }
}

@Model
final class CadenceTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String
    var dueDate: Date?
    var completed: Bool
    var createdAt: Date
    var updatedAt: Date
    var priorityRawValue: String
    var listId: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        dueDate: Date? = nil,
        completed: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        priority: TaskPriority = .none,
        listId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.completed = completed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.priorityRawValue = priority.rawValue
        self.listId = listId
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRawValue) ?? .none }
        set {
            priorityRawValue = newValue.rawValue
            updatedAt = Date()
        }
    }
}
