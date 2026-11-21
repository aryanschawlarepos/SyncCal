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
