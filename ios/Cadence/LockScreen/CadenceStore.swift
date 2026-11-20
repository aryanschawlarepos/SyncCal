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

private func moveLegacyCadenceStore(from legacyStore: URL, to groupStore: URL) throws {
    let fileManager = FileManager.default
    let destinationDirectory = groupStore.deletingLastPathComponent()
    try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

    let sourceDirectory = legacyStore.deletingLastPathComponent()
    for name in ["default.store", "default.store-wal", "default.store-shm"] {
        let source = sourceDirectory.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: source.path) else { continue }
        let destination = destinationDirectory.appendingPathComponent(name)
        guard !fileManager.fileExists(atPath: destination.path) else { continue }
        try fileManager.moveItem(at: source, to: destination)
    }
}
