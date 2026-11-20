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
    private let container: ModelContainer = {
        do {
            return try makeCadenceContainer()
        } catch {
            fatalError("Could not open the Cadence store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
