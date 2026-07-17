//
//  TaskSeedService.swift
//  Cadence
//

import Foundation
import SwiftData

enum TaskSeedService {
    static func seedDefaultListsIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<TaskList>()
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        ["Personal", "Work"].enumerated().forEach { index, name in
            context.insert(TaskList(name: name, sortIndex: index))
        }

        try? context.save()
    }
}
