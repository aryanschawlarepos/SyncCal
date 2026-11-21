//
//  AddTaskControl.swift
//  CadenceLockScreen
//

import AppIntents
import SwiftUI
import WidgetKit

struct AddTaskControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.rork.Cadence.addTask") {
            ControlWidgetButton(action: AddLockScreenTaskIntent()) {
                Label("Add Task", systemImage: "plus")
            }
        }
        .displayName("Add Task")
        .description("Add a Cadence task and show it on the Lock Screen.")
    }
}

struct AddLockScreenTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var openAppWhenRun = false

    @Parameter(title: "Title")
    var title: String?

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct CompleteLockScreenTaskIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Task"
    static var openAppWhenRun = false

    @Parameter(title: "Task")
    var taskID: String

    init() {
        taskID = ""
    }

    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        .result()
    }
}
