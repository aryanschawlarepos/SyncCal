# Planner Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a native Planner tab that shows today's all-day and timed events on a dynamic 8:00 AM-based timeline using the existing theme and calendar store.

**Architecture:** Wrap the authorized app content in a shared `TabView` containing the existing `CalendarHomeView` and a new `PlannerView`. Add a pure `PlannerTimeline` helper for calculating the visible bounds, then let `PlannerView` render all-day rows and positioned timed event rows from the shared `CalendarStore`.

**Tech Stack:** SwiftUI, EventKit-backed `CalendarStore`, Swift Testing, XCTest, Xcode project `ios/Cadence.xcodeproj`.

## Global Constraints

- Keep all changes local; do not upload or commit them.
- Preserve `Theme.background`, `Theme.surface`, `Theme.accent`, and existing dark color scheme.
- Planner is anchored to `Date()` and uses `CalendarStore.events(on:)`.
- Timed bounds default to 8:00 AM-8:00 PM when there are no timed events; with timed events, the end is the latest task and the start expands earlier than 8:00 AM when necessary.
- All-day events do not affect timed bounds.

---

### Task 1: Add Pure Timeline Bounds

**Files:**
- Create: `ios/Cadence/Utilities/PlannerTimeline.swift`
- Modify: `ios/CadenceTests/CadenceTests.swift`

**Interfaces:**
- Produces `PlannerTimeline.bounds(for:calendar:) -> ClosedRange<Date>` for use by `PlannerView`.

- [ ] **Step 1: Write the failing tests**

Add tests that construct `EventItem` values and verify `PlannerTimeline.bounds` returns 8:00 AM-8:00 PM for no timed events, keeps that range for in-hours events, expands for a 7:00 AM event, and expands for a 9:30 PM ending event. Include an all-day event and verify it does not change the bounds.

- [ ] **Step 2: Run the focused test to verify failure**

Run from the repository root:

```powershell
xcodebuild test -project ios/Cadence.xcodeproj -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:CadenceTests/CadenceTests
```

Expected: FAIL because `PlannerTimeline` does not exist.

- [ ] **Step 3: Implement the minimal pure helper**

Create `PlannerTimeline` with 8:00 AM and 8:00 PM defaults based on the supplied calendar and day. Filter `isAllDay == false`; use the minimum timed start and maximum timed end to expand the range.

- [ ] **Step 4: Run the focused tests**

Run the same `xcodebuild test` command. Expected: all timeline-bound tests PASS.

### Task 2: Build the Planner View

**Files:**
- Create: `ios/Cadence/Views/PlannerView.swift`
- Modify: `ios/Cadence/Views/EventRow.swift` only if a small shared style adjustment is required

**Interfaces:**
- Consumes `CalendarStore` and `NotificationManager` exactly like `CalendarHomeView`.
- Uses `PlannerTimeline.bounds(for:calendar:)` from Task 1.

- [ ] **Step 1: Write the failing view-level test expectation**

Add a UI test assertion for a `Planner` tab label and a `Today`/current weekday label after tapping Planner. The test should use accessibility identifiers on the new tab content where text alone is not stable.

- [ ] **Step 2: Run the UI test to verify failure**

Run:

```powershell
xcodebuild test -project ios/Cadence.xcodeproj -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:CadenceUITests/CadenceUITests/testPlannerTab
```

Expected: FAIL because the Planner tab and view are not implemented.

- [ ] **Step 3: Implement the planner layout**

Create a dark `ZStack` using `Theme.background` and `Theme.glow`. Render a header with `Planner`, today's weekday/date, and the existing plus action. Render all-day events in chronological order above a scrollable timeline. Render hourly grid rows from the calculated lower bound through the calculated upper bound, and overlay timed event cards using their `tint`, title, range, and optional location. Use the existing context-menu deletion action and open `EventEditorView` with today's date.

- [ ] **Step 4: Run the UI test**

Run the focused UI test again. Expected: PASS with the Planner tab discoverable and current-day content visible.

### Task 3: Add the Shared Tab Container

**Files:**
- Create: `ios/Cadence/Views/MainTabView.swift`
- Modify: `ios/Cadence/ContentView.swift`

**Interfaces:**
- `MainTabView(store:notifications:)` owns the two top-level tabs and passes the shared dependencies to both screens.

- [ ] **Step 1: Implement the tab shell**

Create a `TabView` with `CalendarHomeView` tagged `.calendar` and `PlannerView` tagged `.planner`. Use `calendar` and `list.bullet.rectangle` SF Symbols, and apply `Theme` colors to the tab bar accent. Replace the authorized branch in `ContentView` with `MainTabView(store: store, notifications: notifications)`.

- [ ] **Step 2: Run the focused UI test and full tests**

Run the Planner UI test, then the complete suite:

```powershell
xcodebuild test -project ios/Cadence.xcodeproj -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: exit code 0 with no test failures.

### Task 4: Verify Requirements and Local Diff

**Files:**
- Inspect all files changed above.

- [ ] **Step 1: Check formatting and diff integrity**

Run:

```powershell
git diff --check
git status --short
```

Confirm the spec, plan, and implementation files remain local and no unrelated files changed.

- [ ] **Step 2: Verify behavior manually in the simulator**

Launch the app with Calendar access, switch between Calendar and Planner, confirm today's events appear in chronological order, confirm event colors match their calendars, and confirm the timeline ends at the latest required task rather than rendering unused hours.
