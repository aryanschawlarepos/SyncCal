//
//  ListLiveActivity.swift
//  CadenceLockScreen
//

import AppIntents
import SwiftUI
import WidgetKit

struct ListLiveActivity: Widget {
    static let kind = "com.rork.Cadence.listActivity"

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ListActivityAttributes.self) { context in
            ListActivityLockScreen(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    ListActivityRows(rows: context.state.rows)
                }
            } compactLeading: {
                Text(context.state.name)
            } compactTrailing: {
                Text("\(context.state.openCount)")
            } minimal: {
                Image(systemName: "checklist")
            }
        }
    }
}

private enum LockScreenPalette {
    static let standardBackground = Color(red: 32.0 / 255.0, green: 32.0 / 255.0, blue: 42.0 / 255.0)
    static let completed = Color(red: 138.0 / 255.0, green: 215.0 / 255.0, blue: 193.0 / 255.0)

    static func background(for appearance: LockScreenAppearance) -> Color {
        switch appearance {
        case .standard:
            standardBackground
        case .transparent:
            Color.clear
        }
    }
}

private struct ListActivityLockScreen: View {
    let state: ListActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(state.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(state.openCount)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            ListActivityRows(rows: state.rows)
        }
        .foregroundStyle(.white)
        .containerBackground(LockScreenPalette.background(for: state.appearance), for: .widget)
    }
}

private struct ListActivityRows: View {
    let rows: [LockScreenTaskRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows) { row in
                Button(intent: CompleteLockScreenTaskIntent(taskID: row.id.uuidString)) {
                    HStack(spacing: 8) {
                        Image(systemName: row.completed ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(row.completed ? LockScreenPalette.completed : Color.white)
                        Text(row.title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .strikethrough(row.completed)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
