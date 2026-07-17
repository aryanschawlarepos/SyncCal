//
//  CadenceApp.swift
//  Cadence
//
//  Created by Rork on July 16, 2026.
//

import SwiftData
import SwiftUI

@main
struct CadenceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [CadenceTask.self, TaskList.self])
    }
}
