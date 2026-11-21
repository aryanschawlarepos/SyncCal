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
                    ListActivityRows(rows: context.state.rows, appearance: .dark)
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
    static let darkBackground = Color(red: 32.0 / 255.0, green: 32.0 / 255.0, blue: 42.0 / 255.0)
    static let lightBackground = Color(red: 245.0 / 255.0, green: 245.0 / 255.0, blue: 247.0 / 255.0)
    static let lightForeground = Color(red: 28.0 / 255.0, green: 28.0 / 255.0, blue: 30.0 / 255.0)
    static let completed = Color(red: 138.0 / 255.0, green: 215.0 / 255.0, blue: 193.0 / 255.0)
    /// Matches Yike’s lock-screen task title: New York / system serif, bold, ~17pt.
    static let titleFont = Font.system(size: 17, weight: .semibold, design: .serif)

    static func foreground(for appearance: LockScreenAppearance) -> Color {
        switch appearance {
        case .light:
            lightForeground
        case .dark, .transparent:
            .white
        }
    }
}

private struct ListActivityLockScreen: View {
    let state: ListActivityAttributes.ContentState

    var body: some View {
        ListActivityRows(rows: state.rows, appearance: state.appearance)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(LockScreenPalette.foreground(for: state.appearance))
            .modifier(LockScreenActivityChrome(appearance: state.appearance))
    }
}

/// Lock Screen Live Activities ignore a clear `containerBackground` and fill with an
/// opaque dark card. `activityBackgroundTint(.clear)` is what lets the wallpaper
/// show through the way Yike’s transparent activity does.
private struct LockScreenActivityChrome: ViewModifier {
    let appearance: LockScreenAppearance

    func body(content: Content) -> some View {
        switch appearance {
        case .light:
            content
                .containerBackground(LockScreenPalette.lightBackground, for: .widget)
                .activityBackgroundTint(LockScreenPalette.lightBackground)
                .activitySystemActionForegroundColor(LockScreenPalette.lightForeground)
        case .dark:
            content
                .containerBackground(LockScreenPalette.darkBackground, for: .widget)
                .activityBackgroundTint(LockScreenPalette.darkBackground)
                .activitySystemActionForegroundColor(.white)
        case .transparent:
            content
                .containerBackground(.clear, for: .widget)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.white)
        }
    }
}

private struct ListActivityRows: View {
    let rows: [LockScreenTaskRow]
    let appearance: LockScreenAppearance

    var body: some View {
        let ink = LockScreenPalette.foreground(for: appearance)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(rows) { row in
                Button(intent: CompleteLockScreenTaskIntent(taskID: row.id.uuidString)) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: row.completed ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(row.completed ? LockScreenPalette.completed : ink)
                        Text(row.title)
                            .font(LockScreenPalette.titleFont)
                            .strikethrough(row.completed)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
