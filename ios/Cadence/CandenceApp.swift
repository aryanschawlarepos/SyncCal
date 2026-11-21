//
//  CadenceApp.swift
//  Cadence
//
//  Created by Rork on July 16, 2026.
//

import SwiftData
import SwiftUI
import UIKit

@main
struct CadenceApp: App {
    private let container: ModelContainer

    init() {
        CadenceAppLaunch.openURL = { url in
            await UIApplication.shared.open(url)
        }
        do {
            let container = try makeCadenceContainer()
            CadenceSharedContainer.container = container
            self.container = container
        } catch {
            fatalError("Could not open the Cadence store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
