# Lock Screen Tasks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put a pinned Cadence list on the Lock Screen and Dynamic Island, with strike-through batches of three and a lock-screen control that asks for a title.

**Architecture:** A pure resolver owns the batch rules. The app and a new widget extension share those types, the ActivityKit attributes, and one App Group SwiftData store. The app starts and refreshes activities. The extension draws the card and the add control. Complete and add run as App Intents against that store.

**Tech Stack:** SwiftUI, SwiftData, ActivityKit, WidgetKit, App Intents, Swift Testing, Xcode project `ios/Cadence.xcodeproj`, scheme `Cadence`.

**Spec:** `docs/superpowers/specs/2026-11-20-lock-screen-tasks-design.md`

## Global Constraints

- Deployment target is iOS 18.5. Bundle id is `com.rork.Cadence`. The extension bundle id is `com.rork.Cadence.LockScreen`. The App Group is `group.com.rork.Cadence`.
- My Day means an incomplete task whose due date is today. A My Day task created from the lock screen gets `dueDate = now` and `listId = nil`.
- A custom-list task created from the lock screen gets that `listId` and `dueDate = nil`.
- Open-task order matches `TaskListSnapshot`: due date ascending, then newer `createdAt` first. Tasks with no due date sort after tasks with one.
- Completing a task sets `completed = true` and `updatedAt = now`. A struck-through circle does not reopen it.
- The card holds at most three rows. A completed, deleted, or out-of-scope row is not replaced while any remaining row is still open.
- When every remaining row is crossed out and more incomplete tasks exist, replace the card with the first three of those. When none exist and rows remain, keep the struck-through card. When none exist and no rows remain, end the activity.
- The header count is every incomplete task in the scope, including tasks waiting off the card.
- Add calls `requestValue` on every use and does not remember a title. A blank or whitespace-only title saves nothing. If iOS will not collect the title, open `cadence://lock-screen-add` to one title field, not `TaskEditorView`.
- Add lands on the running activity with the latest `pinnedAt`. If none are running, it lands on My Day and that activity starts. Equal `pinnedAt` values break toward the greater `scope.id`.
- Standard and Transparent are the only appearances, stored as `standard` and `transparent` under the key `lockScreenAppearance` in the app-group `UserDefaults`. Transparent is a clear container background. The Tasks picker and the intents both use that suite, not `UserDefaults.standard`.
- Pin My Day and custom lists only. Upcoming, All Tasks, and Completed get no pin action. Pinning an empty list does not start an activity. Pinning a list that is already running refreshes it and does not change `pinnedAt`.
- Remove ends that list’s activity only. The activity does not dismiss itself while struck-through rows remain.
- Do not create a second task database. If the group store file is absent and the legacy store exists, move the legacy store. If the group store file exists, open it and leave the legacy file alone.

## Review Focus

- One or two open tasks must still appear on the card. A person expects those rows, not a blank activity and not padded placeholders.
- The header count must include tasks waiting behind the three rows. A person reading `8` expects eight open tasks in the list.
- A whitespace title must not create a task. A person who dismisses the prompt empty expects the list unchanged.
- With several lists on the lock screen, add must use the one pinned latest. A person expects the task on the list they just put up.
- The last struck-through card must stay up. A person who checks the final task expects to see it crossed out until they swipe the activity away.

## File structure

- Create `ios/Cadence/LockScreen/LockScreenBatch.swift` for the pure rules. Task 3 moves it to `ios/CadenceShared/LockScreenBatch.swift` and both the app and the extension compile that folder.
- Create `ios/Cadence/LockScreen/CadenceStore.swift` for the group-store decision and container. Task 3 moves it to `ios/CadenceShared/CadenceStore.swift`.
- Modify `ios/Cadence/CandenceApp.swift` to open that container.
- Create `ios/Cadence/Cadence.entitlements` and `ios/CadenceLockScreen/CadenceLockScreen.entitlements`.
- Create `ios/CadenceLockScreen/CadenceLockScreenBundle.swift`, `ListLiveActivity.swift`, and `AddTaskControl.swift`.
- Create `ios/CadenceShared/ListLiveActivityCenter.swift` for pin, unpin, and refresh.
- Create `ios/CadenceShared/LockScreenIntents.swift` for complete, add, and the title-field save path.
- Create `ios/Cadence/LockScreen/LockScreenTitlePrompt.swift` for the one-field fallback.
- Modify `ios/Cadence/Views/TaskListDetailView.swift`, `ios/Cadence/Views/TasksView.swift`, `ios/Cadence/Views/MainTabView.swift`, and `ios/Cadence/ContentView.swift` for pin, appearance, refresh, and the fallback field.
- Test in `ios/CadenceTests/CadenceTests.swift`.
- Modify `ios/Cadence.xcodeproj/project.pbxproj` and the shared `Cadence` scheme so the app embeds the extension.

`ios/Cadence/` is a synchronized root, so files added there join the app target without a `pbxproj` edit. `ios/CadenceShared/` and `ios/CadenceLockScreen/` do not, so Task 3 adds them.

---

### Task 1: Lock screen batch rules

**Files:**
- Create: `ios/Cadence/LockScreen/LockScreenBatch.swift`
- Test: `ios/CadenceTests/CadenceTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `enum LockScreenScope: Hashable, Codable, Equatable { case myDay; case list(UUID); var id: String { get }; static func scope(id: String) -> LockScreenScope? }`
  - `id` is `"myDay"` or `uuid.uuidString`. `scope(id:)` returns nil for any other string.
  - `enum LockScreenAppearance: String, Codable, Hashable, CaseIterable { case standard; case transparent }`
  - `struct LockScreenSourceTask: Equatable { var id: UUID; var title: String; var completed: Bool; var dueDate: Date?; var listId: UUID?; var createdAt: Date }`
  - `struct LockScreenTaskRow: Hashable, Codable, Equatable, Identifiable { var id: UUID; var title: String; var completed: Bool }`
  - `enum LockScreenCardState: Equatable { case ended; case showing(rows: [LockScreenTaskRow], openCount: Int) }`
  - `func resolveLockScreenCard(scope: LockScreenScope, tasks: [LockScreenSourceTask], currentIDs: [UUID], today: Date, calendar: Calendar) -> LockScreenCardState`
  - `enum LockScreenActivityCommand: Equatable { case skip; case start; case update; case end }`
  - `func lockScreenActivityCommand(state: LockScreenCardState, isRunning: Bool) -> LockScreenActivityCommand`
  - `func lockScreenAddDestination(running: [(scope: LockScreenScope, pinnedAt: Date)]) -> LockScreenScope`
  - `func normalizedLockScreenTitle(_ text: String) -> String?`
  - `func lockScreenWriteCompletion(isCompleted: Bool) -> Bool?`
  - `enum LockScreenPinError: Equatable { case empty; case disabled; case system(String) }`
  - `func lockScreenPinError(activitiesEnabled: Bool, state: LockScreenCardState) -> LockScreenPinError?`
  - `struct ListActivityAttributes: ActivityAttributes { var scopeID: String; var pinnedAt: Date; struct ContentState: Codable, Hashable { var name: String; var openCount: Int; var rows: [LockScreenTaskRow]; var appearance: LockScreenAppearance } }`
  - `func lockScreenContent(name: String, state: LockScreenCardState, appearance: LockScreenAppearance) -> ListActivityAttributes.ContentState?`

- [ ] **Step 1: Write the failing tests**

Append these tests to `CadenceTests`. Use a Gregorian UTC calendar and a fixed today of 2026-11-20 00:00 UTC. Helper `source(title:due:list:completed:createdHour:)` builds a `LockScreenSourceTask` with a stable id from the title.

```swift
@Test func fewerThanThreeOpenTasksStillShow() {
    let tasks = [source("Milk", due: today), source("Email", due: today)]

    let card = resolveLockScreenCard(scope: .myDay, tasks: tasks, currentIDs: [], today: today, calendar: calendar)

    #expect(card == .showing(rows: [row("Milk"), row("Email")], openCount: 2))
}

@Test func openCountIncludesTasksWaitingOffTheCard() {
    let tasks = (1...4).map { source("T\($0)", due: today, createdHour: $0) }

    let card = resolveLockScreenCard(scope: .myDay, tasks: tasks, currentIDs: [], today: today, calendar: calendar)

    guard case .showing(let rows, let openCount) = card else {
        Issue.record("expected a card")
        return
    }
    #expect(rows.map(\.title) == ["T4", "T3", "T2"])
    #expect(openCount == 4)
}

@Test func completedRowStaysAndDoesNotBackfill() {
    let milk = source("Milk", due: today)
    let call = source("Call", due: today, completed: true)
    let email = source("Email", due: today)
    let later = source("Later", due: today)
    let ids = [milk.id, call.id, email.id]

    let card = resolveLockScreenCard(scope: .myDay, tasks: [milk, call, email, later], currentIDs: ids, today: today, calendar: calendar)

    #expect(card == .showing(rows: [row("Milk"), row("Call", completed: true), row("Email")], openCount: 3))
}

@Test func deletedRowDropsWithoutBackfill() {
    let milk = source("Milk", due: today)
    let email = source("Email", due: today)
    let later = source("Later", due: today)
    let missing = UUID()

    let card = resolveLockScreenCard(scope: .myDay, tasks: [milk, email, later], currentIDs: [milk.id, missing, email.id], today: today, calendar: calendar)

    #expect(card == .showing(rows: [row("Milk"), row("Email")], openCount: 3))
}

@Test func batchAdvancesOnlyWhenEveryRemainingRowIsCrossedOut() {
    let done = (1...3).map { source("D\($0)", due: today, completed: true, createdHour: $0) }
    let next = [source("N1", due: today, createdHour: 4), source("N2", due: today, createdHour: 5)]

    let card = resolveLockScreenCard(scope: .myDay, tasks: done + next, currentIDs: done.map(\.id), today: today, calendar: calendar)

    #expect(card == .showing(rows: [row("N2"), row("N1")], openCount: 2))
}

@Test func finishedBatchStaysAndDoesNotEndTheActivity() {
    let done = [source("Milk", due: today, completed: true), source("Call", due: today, completed: true)]

    let card = resolveLockScreenCard(scope: .myDay, tasks: done, currentIDs: done.map(\.id), today: today, calendar: calendar)

    #expect(card == .showing(rows: [row("Milk", completed: true), row("Call", completed: true)], openCount: 0))
    #expect(lockScreenActivityCommand(state: card, isRunning: true) == .update)
}

@Test func newTaskWaitsUntilTheBatchIsFinished() {
    let milk = source("Milk", due: today)
    let extra = source("Extra", due: today)

    let card = resolveLockScreenCard(scope: .myDay, tasks: [milk, extra], currentIDs: [milk.id], today: today, calendar: calendar)

    #expect(card == .showing(rows: [row("Milk")], openCount: 2))
}

@Test func newTaskReplacesAFinishedBatch() {
    let done = source("Milk", due: today, completed: true)
    let extra = source("Extra", due: today)

    let card = resolveLockScreenCard(scope: .myDay, tasks: [done, extra], currentIDs: [done.id], today: today, calendar: calendar)

    #expect(card == .showing(rows: [row("Extra")], openCount: 1))
}

@Test func taskThatLeavesTheScopeDropsOff() {
    let list = UUID()
    let stayed = source("Stay", list: list)
    let moved = source("Moved", list: UUID())
    let waiting = source("Wait", list: list)

    let card = resolveLockScreenCard(scope: .list(list), tasks: [stayed, moved, waiting], currentIDs: [stayed.id, moved.id], today: today, calendar: calendar)

    #expect(card == .showing(rows: [row("Stay")], openCount: 2))
}

@Test func myDayDropsATaskWhoseDueDateIsNoLongerToday() {
    let stayed = source("Stay", due: today)
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
    let left = source("Left", due: tomorrow, completed: true)

    let card = resolveLockScreenCard(scope: .myDay, tasks: [stayed, left], currentIDs: [stayed.id, left.id], today: today, calendar: calendar)

    #expect(card == .showing(rows: [row("Stay")], openCount: 1))
}

@Test func emptyScopeEndsARunningActivityAndSkipsANewOne() {
    let card = resolveLockScreenCard(scope: .myDay, tasks: [], currentIDs: [], today: today, calendar: calendar)

    #expect(card == .ended)
    #expect(lockScreenActivityCommand(state: card, isRunning: true) == .end)
    #expect(lockScreenActivityCommand(state: card, isRunning: false) == .skip)
}

@Test func whitespaceTitleIsIgnoredAndARealTitleIsTrimmed() {
    #expect(normalizedLockScreenTitle("   ") == nil)
    #expect(normalizedLockScreenTitle("\n") == nil)
    #expect(normalizedLockScreenTitle("  Milk  ") == "Milk")
}

@Test func addTargetsTheLatestPinnedListAndOtherwiseMyDay() {
    let older = UUID()
    let newer = UUID()
    let running: [(scope: LockScreenScope, pinnedAt: Date)] = [
        (.list(older), today),
        (.list(newer), today.addingTimeInterval(10))
    ]

    #expect(lockScreenAddDestination(running: []) == .myDay)
    #expect(lockScreenAddDestination(running: running) == .list(newer))
    #expect(lockScreenAddDestination(running: [(.list(older), today), (.myDay, today)]) == .myDay)
}

@Test func struckThroughCircleDoesNotReopen() {
    #expect(lockScreenWriteCompletion(isCompleted: false) == true)
    #expect(lockScreenWriteCompletion(isCompleted: true) == nil)
}

@Test func pinErrorPrefersADisabledSystemOverAnEmptyList() {
    #expect(lockScreenPinError(activitiesEnabled: false, state: .ended) == .disabled)
    #expect(lockScreenPinError(activitiesEnabled: true, state: .ended) == .empty)
    #expect(lockScreenPinError(activitiesEnabled: true, state: .showing(rows: [row("Milk")], openCount: 1)) == nil)
}

@Test func contentCarriesTheWaitingCountAndTheAppearance() {
    let card = LockScreenCardState.showing(rows: [row("Milk")], openCount: 8)

    let content = lockScreenContent(name: "My Day", state: card, appearance: .transparent)

    #expect(content?.name == "My Day")
    #expect(content?.openCount == 8)
    #expect(content?.rows == [row("Milk")])
    #expect(content?.appearance == .transparent)
    #expect(lockScreenContent(name: "My Day", state: .ended, appearance: .standard) == nil)
}
```

Same-due-date order is newer `createdAt` first, which is why four tasks created at hours 1...4 show `T4`, `T3`, `T2`. The helper’s default `createdAt` is one fixed date, and the sort is Swift’s stable sort, so a tie keeps input order. Equal `pinnedAt` values compare `scope.id` with `>`. `"myDay"` is greater than any `UUID.uuidString`, so the tie in the destination test resolves to `.myDay`.

- [ ] **Step 2: Run the tests to verify they fail**

Run from the repo root:

```bash
xcodebuild test -project ios/Cadence.xcodeproj -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:CadenceTests/CadenceTests
```

Expected: FAIL because `resolveLockScreenCard` is not defined. If that simulator is not installed, rerun the same test filter with an installed iPhone simulator.

- [ ] **Step 3: Implement the signatures from this task’s Interfaces in `ios/Cadence/LockScreen/LockScreenBatch.swift`**

Apply the batch rules in Global Constraints. `openCount` counts incomplete tasks still in scope, not the rows. `lockScreenActivityCommand` returns `.end` only for `.ended` while running, `.skip` for `.ended` while not running, `.update` while running, and `.start` while not. `lockScreenPinError` returns `.disabled` when activities are off, without looking at the card. `lockScreenContent` returns nil for `.ended`.

- [ ] **Step 4: Run the tests to verify they pass**

Run the same `xcodebuild test` command. Expected: the new tests PASS, and the existing planner tests still PASS.

- [ ] **Step 5: Commit**

```bash
git add ios/Cadence/LockScreen/LockScreenBatch.swift ios/CadenceTests/CadenceTests.swift
git commit -m "feat: add lock screen batch rules"
```

---

### Task 2: Shared SwiftData store

**Files:**
- Create: `ios/Cadence/LockScreen/CadenceStore.swift`
- Create: `ios/Cadence/Cadence.entitlements`
- Modify: `ios/Cadence/CandenceApp.swift`
- Modify: `ios/Cadence.xcodeproj/project.pbxproj` (Cadence Debug and Release: `CODE_SIGN_ENTITLEMENTS = Cadence/Cadence.entitlements`)
- Test: `ios/CadenceTests/CadenceTests.swift`

**Interfaces:**
- Consumes: nothing from Task 1
- Produces:
  - `enum CadenceAppGroup { static let identifier = "group.com.rork.Cadence"; static let fallbackScopeKey = "lockScreenAddFallbackScope"; static let addURL = URL(string: "cadence://lock-screen-add")! }`
  - `enum CadenceStoreRelocation: Equatable { case useGroup; case moveLegacy }`
  - `func cadenceStoreRelocation(groupStoreReady: Bool, legacyStoreExists: Bool) -> CadenceStoreRelocation`
  - `func legacyCadenceStoreURL(applicationSupport: URL) -> URL` returns `applicationSupport/default.store`
  - `func cadenceGroupStoreURL(groupContainer: URL) -> URL` returns `groupContainer/Library/Application Support/default.store`
  - `func makeCadenceContainer() throws -> ModelContainer` opens `CadenceTask` and `TaskList` at the group URL

- [ ] **Step 1: Write the failing relocation tests**

```swift
@Test func groupStoreWinsWhenItAlreadyExists() {
    #expect(cadenceStoreRelocation(groupStoreReady: true, legacyStoreExists: true) == .useGroup)
    #expect(cadenceStoreRelocation(groupStoreReady: true, legacyStoreExists: false) == .useGroup)
}

@Test func legacyStoreMovesOnlyWhenTheGroupStoreIsMissing() {
    #expect(cadenceStoreRelocation(groupStoreReady: false, legacyStoreExists: true) == .moveLegacy)
    #expect(cadenceStoreRelocation(groupStoreReady: false, legacyStoreExists: false) == .useGroup)
}

@Test func storeURLsUseTheSwiftDataDefaultName() {
    let support = URL(fileURLWithPath: "/tmp/support")
    let group = URL(fileURLWithPath: "/tmp/group")

    #expect(legacyCadenceStoreURL(applicationSupport: support).lastPathComponent == "default.store")
    #expect(cadenceGroupStoreURL(groupContainer: group).path.hasSuffix("/Library/Application Support/default.store"))
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the Task 1 `xcodebuild test` command. Expected: FAIL because `cadenceStoreRelocation` is not defined.

- [ ] **Step 3: Implement the store**

`cadenceStoreRelocation` follows the two tests. `makeCadenceContainer` resolves the group container with `CadenceAppGroup.identifier`. When the relocation is `.moveLegacy`, create the destination directory and move `default.store`, `default.store-wal`, and `default.store-shm` from the app’s Application Support directory. Skip a sidecar that is not there. Do not overwrite a destination file. Then open `ModelConfiguration` at `cadenceGroupStoreURL`. Entitlements contain only the app group `group.com.rork.Cadence`. Point `CandenceApp` at `try makeCadenceContainer()` instead of `.modelContainer(for:)`.

- [ ] **Step 4: Run the tests to verify they pass**

Run the same `xcodebuild test` command. Expected: PASS, including Task 1.

- [ ] **Step 5: Commit**

```bash
git add ios/Cadence/LockScreen/CadenceStore.swift ios/Cadence/Cadence.entitlements ios/Cadence/CandenceApp.swift ios/CadenceTests/CadenceTests.swift ios/Cadence.xcodeproj/project.pbxproj
git commit -m "feat: store Cadence tasks in the app group"
```

---

### Task 3: Lock screen extension

**Files:**
- Move: `ios/Cadence/LockScreen/LockScreenBatch.swift` and `CadenceStore.swift` to `ios/CadenceShared/`
- Move: `ios/Cadence/Models/CadenceTask.swift` and `TaskList.swift` to `ios/CadenceShared/`
- Create: `ios/CadenceLockScreen/CadenceLockScreenBundle.swift`
- Create: `ios/CadenceLockScreen/ListLiveActivity.swift`
- Create: `ios/CadenceLockScreen/AddTaskControl.swift`
- Create: `ios/CadenceLockScreen/CadenceLockScreen.entitlements`
- Modify: `ios/Cadence.xcodeproj/project.pbxproj`
- Modify: `ios/Cadence.xcodeproj/xcshareddata/xcschemes/Cadence.xcscheme`

**Interfaces:**
- Consumes: Task 1 attributes and Task 2 `CadenceAppGroup`
- Produces:
  - Widget kind `com.rork.Cadence.listActivity`
  - Control kind `com.rork.Cadence.addTask`
  - `ListLiveActivity` renders `ListActivityAttributes.ContentState`
  - `AddTaskControl` runs `AddLockScreenTaskIntent`, defined in Task 5. Declare the intent type in this task as an empty `AppIntent` with `static var openAppWhenRun = false`, `@Parameter(title: "Title") var title: String?`, and a `perform` that returns `.result()`. Task 5 replaces `perform`.

- [ ] **Step 1: Move the shared files and add the extension target**

Remove the moved files from `ios/Cadence/` so the synchronized app folder does not compile them twice. Add synchronized root groups for `CadenceShared` and `CadenceLockScreen`. `CadenceShared` belongs to the Cadence app target and the CadenceLockScreen target only. CadenceTests sees those types through `@testable import Cadence` and must not compile the folder itself. `CadenceLockScreen` belongs only to the extension.

Extension settings, Debug and Release: product type `com.apple.product-type.app-extension`, bundle id `com.rork.Cadence.LockScreen`, deployment target iOS 18.5, Swift 5, `DEVELOPMENT_TEAM = 8BDJWZ67Y7`, `GENERATE_INFOPLIST_FILE = YES`, `INFOPLIST_KEY_NSSupportsLiveActivities = YES`, `INFOPLIST_KEY_NSExtensionPointIdentifier = com.apple.widgetkit-extension`, `CODE_SIGN_ENTITLEMENTS = CadenceLockScreen/CadenceLockScreen.entitlements`, skip install YES. The extension entitlements file contains the same app group as the app.

Cadence Debug and Release gain `INFOPLIST_KEY_NSSupportsLiveActivities = YES` and this URL type through an `INFOPLIST_FILE` that Xcode merges with the generated plist:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>cadence</string></array>
  </dict>
</array>
```

Embed `CadenceLockScreen.appex` in Cadence with a PlugIns copy phase and a target dependency. Add the extension to the Cadence scheme’s build action.

- [ ] **Step 2: Draw the activity and the control**

`CadenceLockScreenBundle` is `@main` and contains `ListLiveActivity` and `AddTaskControl`.

`ListLiveActivity` uses `ActivityConfiguration(for: ListActivityAttributes.self)`. The lock-screen view shows `state.name`, `state.openCount`, and `state.rows` in order. An open row uses `circle`. A completed row uses `checkmark.circle.fill` in `#8AD7C1` and a strikethrough title. The title font is rounded semibold 16. Each row’s button sends `CompleteLockScreenTaskIntent(taskID: row.id.uuidString)`. Declare that intent beside the add intent: `LiveActivityIntent`, `openAppWhenRun = false`, `@Parameter(title: "Task") var taskID: String`, `perform` returns `.result()`. Task 5 replaces `perform`.

Standard `containerBackground` is `#20202A`. Transparent is `Color.clear`. The expanded Dynamic Island shows the same rows and buttons. Compact leading is the name, compact trailing is the open count, minimal is `checklist`. Do not end the activity from the view.

`AddTaskControl` is a `StaticControlConfiguration` with display name `Add Task`, system image `plus`, and description `Add a Cadence task and show it on the Lock Screen.` Its button runs `AddLockScreenTaskIntent()`.

- [ ] **Step 3: Build the app and the extension**

```bash
xcodebuild build -project ios/Cadence.xcodeproj -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: BUILD SUCCEEDED, including `CadenceLockScreen`. Then run the Task 1 test command. Expected: PASS. If the simulator name is missing, use an installed iPhone simulator for both commands.

- [ ] **Step 4: Commit**

```bash
git add ios/CadenceShared ios/CadenceLockScreen ios/Cadence ios/Cadence.xcodeproj
git commit -m "feat: add the lock screen activity extension"
```

---

### Task 4: Pin, appearance, and refresh

**Files:**
- Create: `ios/CadenceShared/ListLiveActivityCenter.swift`
- Modify: `ios/CadenceShared/LockScreenBatch.swift`
- Modify: `ios/Cadence/Views/TaskListDetailView.swift`
- Modify: `ios/Cadence/Views/TasksView.swift`
- Modify: `ios/Cadence/Views/MainTabView.swift`

**Interfaces:**
- Consumes: `resolveLockScreenCard`, `lockScreenActivityCommand`, `lockScreenContent`, `lockScreenPinError`, `ListActivityAttributes`, `LockScreenAppearance`
- Produces:
  - `@MainActor enum ListLiveActivityCenter`
  - `static func isRunning(_ scope: LockScreenScope) -> Bool`
  - `static func pin(scope: LockScreenScope, name: String, tasks: [CadenceTask], appearance: LockScreenAppearance) async throws`
  - `static func unpin(_ scope: LockScreenScope) async`
  - `static func sync(tasks: [CadenceTask], lists: [TaskList], appearance: LockScreenAppearance) async`
  - `func lockScreenDisplayName(scope: LockScreenScope, listNames: [UUID: String]) -> String?` returns `My Day`, the custom list’s name, or nil when that list id is absent.
- Map `CadenceTask` to `LockScreenSourceTask` field for field. A running activity whose `lockScreenDisplayName` is nil ends.

- [ ] **Step 1: Write the failing name test**

```swift
@Test func displayNameIsMyDayOrTheCustomList() {
    let list = UUID()

    #expect(lockScreenDisplayName(scope: .myDay, listNames: [:]) == "My Day")
    #expect(lockScreenDisplayName(scope: .list(list), listNames: [list: "Home"]) == "Home")
    #expect(lockScreenDisplayName(scope: .list(list), listNames: [:]) == nil)
}
```

- [ ] **Step 2: Run the tests to verify the name test fails**

Run the Task 1 `xcodebuild test` command. Expected: FAIL because `lockScreenDisplayName` is not defined.

- [ ] **Step 3: Implement the center**

`lockScreenDisplayName` returns `My Day`, the matching list name, or nil. `pin` checks `ActivityAuthorizationInfo().areActivitiesEnabled` and `lockScreenPinError`. `.disabled` throws `LockScreenPinError.disabled`. `.empty` throws `.empty`. An existing activity for that `scope.id` is updated from `lockScreenContent` and keeps its `pinnedAt`. Otherwise `Activity.request` with `pinnedAt = Date()`. `unpin` ends only the activity with that `scope.id`, dismissal `.immediate`. `sync` reads each running activity’s row ids as `currentIDs`, resolves, and applies `lockScreenActivityCommand`: `.update` pushes content, `.end` ends it, `.start` and `.skip` do nothing here. A nil display name ends that activity.

On `TaskListDetailView`, show the action only for `.smart(.myDay)` and `.custom`. The label is `Show on Lock Screen` while stopped and `Remove from Lock Screen` while running. Failure alerts: `.empty` says `Nothing to show on the Lock Screen.` `.disabled` says `Live Activities are turned off.` `.system` shows its message.

On `TasksView`, add a two-option picker labeled `Lock Screen` with `Standard` and `Transparent`. Bind it to `@AppStorage("lockScreenAppearance", store: UserDefaults(suiteName: CadenceAppGroup.identifier)!)`. A missing value is `standard`. Changing it calls `sync`.

In `MainTabView`, query tasks and lists and call `sync` on appear and whenever the tasks, lists, or appearance change, so a check-off on any tab updates the card.

- [ ] **Step 4: Build and test**

Run the Task 3 build command and the Task 1 test command. Expected: BUILD SUCCEEDED and tests PASS.

- [ ] **Step 5: Commit**

```bash
git add ios/CadenceShared/ListLiveActivityCenter.swift ios/CadenceShared/LockScreenBatch.swift ios/Cadence/Views/TaskListDetailView.swift ios/Cadence/Views/TasksView.swift ios/Cadence/Views/MainTabView.swift ios/CadenceTests/CadenceTests.swift
git commit -m "feat: pin a list to the lock screen"
```

---

### Task 5: Complete and add

**Files:**
- Create: `ios/CadenceShared/LockScreenIntents.swift`
- Modify: the Task 3 intent declarations so they call this file instead of returning immediately. Delete the stubs if this file owns both types.
- Create: `ios/Cadence/LockScreen/LockScreenTitlePrompt.swift`
- Modify: `ios/Cadence/ContentView.swift`
- Test: `ios/CadenceTests/CadenceTests.swift`

**Interfaces:**
- Consumes: `normalizedLockScreenTitle`, `lockScreenWriteCompletion`, `lockScreenAddDestination`, `CadenceAppGroup`, `makeCadenceContainer`, `ListLiveActivityCenter`
- Produces:
  - `@MainActor func saveLockScreenTask(title: String, scope: LockScreenScope, now: Date, context: ModelContext) throws -> Bool`
  - `@MainActor func completeLockScreenTask(id: UUID, context: ModelContext) throws -> Bool`
  - `AddLockScreenTaskIntent` and `CompleteLockScreenTaskIntent` and `OpenLockScreenAddIntent`

- [ ] **Step 1: Write the failing save tests**

Use an in-memory container: `ModelConfiguration(isStoredInMemoryOnly: true)` for `CadenceTask` and `TaskList`.

```swift
@Test func whitespaceSaveInsertsNothing() throws {
    let context = try makeMemoryContext()

    let saved = try saveLockScreenTask(title: "  ", scope: .myDay, now: today, context: context)

    #expect(saved == false)
    #expect(try context.fetch(FetchDescriptor<CadenceTask>()).isEmpty)
}

@Test func myDaySaveSetsDueDateAndNoList() throws {
    let context = try makeMemoryContext()
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    let saved = try saveLockScreenTask(title: " Milk ", scope: .myDay, now: now, context: context)
    let task = try context.fetch(FetchDescriptor<CadenceTask>()).first

    #expect(saved == true)
    #expect(task?.title == "Milk")
    #expect(task?.dueDate == now)
    #expect(task?.listId == nil)
    #expect(task?.completed == false)
}

@Test func customListSaveSetsTheListAndNoDueDate() throws {
    let context = try makeMemoryContext()
    let list = UUID()

    _ = try saveLockScreenTask(title: "Milk", scope: .list(list), now: today, context: context)
    let task = try context.fetch(FetchDescriptor<CadenceTask>()).first

    #expect(task?.listId == list)
    #expect(task?.dueDate == nil)
}

@Test func completingATaskOnceMarksItDone() throws {
    let context = try makeMemoryContext()
    _ = try saveLockScreenTask(title: "Milk", scope: .myDay, now: today, context: context)
    let id = try context.fetch(FetchDescriptor<CadenceTask>()).first!.id

    #expect(try completeLockScreenTask(id: id, context: context) == true)
    #expect(try completeLockScreenTask(id: id, context: context) == false)
    #expect(try context.fetch(FetchDescriptor<CadenceTask>()).first?.completed == true)
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the Task 1 `xcodebuild test` command. Expected: FAIL because `saveLockScreenTask` is not defined.

- [ ] **Step 3: Implement save, complete, and the intents**

`saveLockScreenTask` returns false when `normalizedLockScreenTitle` is nil and inserts nothing. Otherwise it inserts a `CadenceTask` with the trimmed title and the Global Constraints’ due date and list id, then saves the context. `completeLockScreenTask` returns false when the id is missing or `lockScreenWriteCompletion` returns nil. Otherwise it sets `completed` and `updatedAt` and saves.

`CompleteLockScreenTaskIntent.perform` parses `taskID` as a UUID, calls `completeLockScreenTask` on `makeCadenceContainer()`, then `ListLiveActivityCenter.sync` with the stored tasks, lists, and the appearance string from the app-group defaults. It does not open the app.

`AddLockScreenTaskIntent.perform` reads running activities into `lockScreenAddDestination`. It then `try await $title.requestValue(IntentDialog("Task title"))`. On failure, write `scope.id` to the app-group defaults under `CadenceAppGroup.fallbackScopeKey` and return `.result(opensIntent: OpenURLIntent(target: CadenceAppGroup.addURL))`. On success, call `saveLockScreenTask`. A false save returns without starting an activity. A true save calls `pin` for that scope when it is not running, then `sync`. `openAppWhenRun` stays false.

`LockScreenTitlePrompt` is one text field, an Add button, and a Cancel button. Add calls `saveLockScreenTask` and then `pin` or `sync` with the same rules. Cancel writes nothing. `ContentView` presents this prompt for `cadence://lock-screen-add` and when the app becomes active with `fallbackScopeKey` set. Clear that key when the prompt appears. The sheet’s root is `LockScreenTitlePrompt`, not `TaskEditorView`.

- [ ] **Step 4: Run the tests and build**

Run the Task 1 test command. Expected: PASS, including the four new tests. Run the Task 3 build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add ios/CadenceShared/LockScreenIntents.swift ios/Cadence/LockScreen/LockScreenTitlePrompt.swift ios/Cadence/ContentView.swift ios/CadenceTests/CadenceTests.swift ios/CadenceLockScreen
git commit -m "feat: complete and add tasks from the lock screen"
```
