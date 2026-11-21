//
//  CadenceStore.swift
//  Cadence
//

import Foundation
import SwiftData

enum CadenceAppGroup {
    static let identifier = "group.com.rork.Cadence"
    static let fallbackScopeKey = "lockScreenAddFallbackScope"
    static let addURL = URL(string: "cadence://lock-screen-add")!
}

enum CadenceStoreRelocation: Equatable {
    case useGroup
    case moveLegacy
}

enum CadenceStoreError: Error {
    case appGroupUnavailable
}

func cadenceStoreRelocation(groupStoreReady: Bool, legacyStoreExists: Bool) -> CadenceStoreRelocation {
    if groupStoreReady || !legacyStoreExists {
        return .useGroup
    }
    return .moveLegacy
}

func legacyCadenceStoreURL(applicationSupport: URL) -> URL {
    applicationSupport.appendingPathComponent("default.store")
}

func cadenceGroupStoreURL(groupContainer: URL) -> URL {
    groupContainer
        .appendingPathComponent("Library")
        .appendingPathComponent("Application Support")
        .appendingPathComponent("default.store")
}

func makeCadenceContainer() throws -> ModelContainer {
    guard let groupContainer = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: CadenceAppGroup.identifier
    ) else {
        throw CadenceStoreError.appGroupUnavailable
    }

    let groupStore = cadenceGroupStoreURL(groupContainer: groupContainer)
    let applicationSupport = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false
    )
    let legacyStore = legacyCadenceStoreURL(applicationSupport: applicationSupport)
    let fileManager = FileManager.default
    let relocation = cadenceStoreRelocation(
        groupStoreReady: fileManager.fileExists(atPath: groupStore.path),
        legacyStoreExists: fileManager.fileExists(atPath: legacyStore.path)
    )

    if relocation == .moveLegacy {
        try moveLegacyCadenceStore(from: legacyStore, to: groupStore)
    } else {
        try fileManager.createDirectory(
            at: groupStore.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    let configuration = ModelConfiguration(url: groupStore)
    return try ModelContainer(for: CadenceTask.self, TaskList.self, configurations: configuration)
}

@MainActor
enum CadenceSharedContainer {
    static var container: ModelContainer?

    static func context() throws -> ModelContext {
        if let container {
            return container.mainContext
        }
        return try makeCadenceContainer().mainContext
    }
}

func moveLegacyCadenceStore(from legacyStore: URL, to groupStore: URL) throws {
    let fileManager = FileManager.default
    let sourceDirectory = legacyStore.deletingLastPathComponent()
    let destinationDirectory = groupStore.deletingLastPathComponent()
    let sourceStore = sourceDirectory.appendingPathComponent("default.store")
    let destinationStore = destinationDirectory.appendingPathComponent("default.store")

    // default.store is the finished signal. Leave a real group store alone.
    if fileManager.fileExists(atPath: destinationStore.path) || !fileManager.fileExists(atPath: sourceStore.path) {
        return
    }

    try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

    // Sidecars land first. A crash before default.store still retries, because the group file is absent.
    for name in ["default.store-wal", "default.store-shm"] {
        let source = sourceDirectory.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: source.path) else { continue }
        let destination = destinationDirectory.appendingPathComponent(name)
        if fileManager.fileExists(atPath: destination.path) {
            let aside = destination.appendingPathExtension("aside")
            if fileManager.fileExists(atPath: aside.path) {
                try fileManager.removeItem(at: aside)
            }
            try fileManager.moveItem(at: destination, to: aside)
        }
        try fileManager.moveItem(at: source, to: destination)
    }

    guard !fileManager.fileExists(atPath: destinationStore.path) else { return }
    try fileManager.moveItem(at: sourceStore, to: destinationStore)
}
