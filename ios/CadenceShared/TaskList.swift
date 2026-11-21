//
//  TaskList.swift
//  Cadence
//

import Foundation
import SwiftData

@Model
final class TaskList {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var sortIndex: Int

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sortIndex: Int
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortIndex = sortIndex
    }
}
