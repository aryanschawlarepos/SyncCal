# Lock Screen Tasks Design

## Intent

Cadence should put a chosen task list on the iPhone Lock Screen and in the Dynamic Island, the way Yike’s list Live Activity does, including a transparent look and adding a task by typing its title on the lock screen.

The person using it wants to see the current batch of tasks, check one off without opening Cadence, and watch that task stay struck through until the batch is finished.

## Goals

- Pin My Day or a custom list to a Live Activity.
- The activity shows that list’s name, how many tasks in the list are still open, and up to three task rows.
- Tapping the open circle completes the task in Cadence and strikes the title through. The row stays in place.
- The next three open tasks replace the card only after every row on the card is crossed out.
- When the list has nothing left open, the finished card stays, all rows struck through, until the person swipes the activity away.
- A lock-screen control asks iOS for a title on each use and saves that task into the list currently on the lock screen. If iOS will not present that prompt, Cadence opens to a single title field and saves from there.
- Appearance is Standard or Transparent, and it applies to every running list activity.
- More than one list can be on the lock screen at once, each with its own activity and its own batch.

## Non-goals

- Home-screen widgets, calendar events on the lock screen, and a focus timer.
- Subtasks, quadrants, and an install-guide with screenshots.
- Completing or reopening a task from the Dynamic Island’s compact presentation.
- Reopening a struck-through task from the lock screen. Reopen stays inside Cadence.
- Pinning Upcoming, All Tasks, or Completed.
- Extra appearance styles beyond Standard and Transparent.

## Anti-goals

- A checked task disappearing immediately, or the next task sliding into its row before the other visible rows are crossed out.
- Add opening Cadence’s full task editor. The only in-app add surface is the one title field, and only when iOS will not present the system prompt.
- Ending the activity automatically on the last check, so the finished card never gets seen.

## Constraints

- Cadence is a SwiftUI app using SwiftData (`CadenceTask`, `TaskList`), bundle id `com.rork.Cadence`, deployment target iOS 18.5. There is no widget extension today.
- Live Activities and lock-screen controls require a Widget Extension target. Interactive buttons use App Intents.
- A lock-screen control cannot contain its own text field. Asking for a title means the intent calls `requestValue` so iOS shows its prompt. iOS may refuse that prompt and require the app to open.
- The system chooses the final Live Activity chrome, height, and how a clear background composites over the wallpaper. Transparent means a clear container background; the wallpaper blend is the system’s.
- A lock-screen card fits about three text rows. The batch size is three for that reason.
- My Day is not a stored list. A task is in My Day when it is incomplete and its due date is today. Creating a My Day task today sets `dueDate` to now, matching `TaskListDetailView.createQuickTask`.
- Custom-list membership is `listId`. Open tasks for a list use `TaskListSnapshot`’s sort: due date ascending, then newer `createdAt` first. Tasks with no due date sort after tasks with one.
- Checking off a task uses the existing rule: `completed = true` and `updatedAt = now`, saved in the same SwiftData store the Tasks tab reads.
- Live Activities must be allowed in system settings. If the system refuses to start one, Cadence shows the error and does not claim the list is on the lock screen.

## Approaches

1. **Widget extension with a Live Activity and an iOS 18 lock-screen control.** The activity shows the batch and completes tasks in place. The control asks iOS for a title on each use. **Chosen.**
2. **Live Activity only, with no lock-screen add.** Rejected. Adding would stay inside Cadence.
3. **A normal widget or a notification.** Rejected. Those cannot check a task off in place and sit in the Dynamic Island.

For the title itself, once the control exists:

1. **System prompt on each use, with a one-field fallback.** The intent calls `requestValue` and does not remember a title. If iOS will not show the prompt, Cadence opens to a single title field. **Chosen.**
2. **Always open Cadence to that field.** Rejected. The keyboard would leave the lock screen every time.
3. **A title saved when the control is added.** Rejected. Each use has to ask again.

## What they decided

- Add uses the system title prompt on each use. If iOS will not show it, Cadence opens to one title field.
- A tap on the circle strikes that task through and leaves the row up.
- The card shows three tasks at a time. The next three appear only after those three are all crossed out.
- The picture they accepted: list name, open count, three rows with circles, and a lock-screen Add control.

## Batch rules

The card is a fixed batch of at most three task ids, stored on the activity. Order inside the batch does not change when a row is completed.

Resolve the card from the pinned scope, the current batch ids, and the tasks in the store:

1. **No current batch.** Take the first three incomplete tasks in that scope, in `TaskListSnapshot` order. If there are none, do not start an activity.
2. **Batch has a row that is not crossed out.** Keep the surviving ids in their current order. Do not append a replacement when a row is completed, deleted, or no longer in the scope. A completed task stays. A deleted task, a task moved to another list, or a My Day task whose due date is no longer today drops off and leaves a shorter card.
3. **Every remaining row is crossed out.** If the scope still has incomplete tasks that are not on this card, replace the card with the first three of those. If none remain and the card still has rows, keep the struck-through card. If none remain and the card is empty, end the activity.
4. **A new open task while any row is still open** waits for a later batch.
5. **A new open task while the card is fully struck through** is an incomplete task under rule 3, so it becomes the next batch. Adding from the lock screen is this case when the finished card is still up. The add is what replaces the finished card.
6. **Completing the same task inside Cadence** updates the activity with the same rules. The lock screen is not a separate completion state.
7. **Tapping a circle that is already struck through** does nothing.

The header count is the number of incomplete tasks still in the scope, including ones waiting for a later batch. It is not the number of open rows on the card.

## Add control

- One system lock-screen control, named so it reads as adding a Cadence task.
- Every use calls `requestValue` for the title. The title is not remembered as the control’s default.
- When `requestValue` returns a title, save the task without bringing Cadence forward.
- When iOS will not collect the value, open Cadence to a single title field. That field is not the task editor. Saving it creates the task with the same rules and dismisses the field. Cancelling it creates nothing.
- Blank or whitespace-only titles do nothing, whether they come from the system prompt or the field.
- The task is saved before the activity updates.
- Destination, when activities are running: the list whose activity started most recently. When none are running: My Day, and that activity starts.
- A task added to My Day gets `dueDate = now` and `listId = nil`.
- A task added to a custom list gets that `listId` and `dueDate = nil`.
- The new task joins the card only through the batch rules above. If the list had no activity yet, the new activity’s first batch includes it when it is among the first three incomplete tasks.

## Appearance

- A Standard / Transparent choice lives on the Tasks screen and is remembered on device.
- Standard draws the activity on Cadence’s elevated surface, with the amber accent, the existing open circle, and the existing strikethrough for a completed title.
- Transparent draws the same content on a clear container background.
- Changing the choice updates every running list activity.
- Both presentations use the same type and the same row layout. The choice is only the background.

## Where it appears in the app

- My Day and each custom list get a Show on Lock Screen action on the list screen. While that list’s activity is running, the action becomes Remove from Lock Screen.
- Upcoming, All Tasks, and Completed do not get the action.
- Remove ends that list’s activity only.
- Showing an empty list does not start an activity; the list screen says there is nothing to show.
- If the system has Live Activities turned off, the action reports that instead of failing silently.

## Lock Screen and Island

Lock Screen card:

```
My Day                      8
○  Buy milk
—  Call dentist —
○  Email
```

`— Call dentist —` is the struck-through row. Its circle is filled. The other circles are open. `8` is the incomplete count for the whole list.

Dynamic Island is required by a Live Activity:

- Compact: list name and the same incomplete count.
- Expanded: the same rows and the same circles, so a tap there completes the task too.
- Minimal: the checklist symbol.

The activity does not dismiss itself when the last task is crossed out.

## How it is built

These are builder calls.

- Add a Widget Extension target to the Cadence Xcode project. The app turns on Live Activities. The extension hosts the list activity and the lock-screen control.
- Share one ActivityKit attributes type between the app and the extension: scope id, and content of list name, incomplete count, appearance, and the batch rows (id, title, completed).
- Put the batch resolver in the app as a pure function of scope, tasks, and current ids. Unit-test that function. The activity UI and the control stay out of the unit tests.
- Give the app and the extension an App Group, `group.com.rork.Cadence`, and point the SwiftData store at that group so a lock-screen intent can save a task while Cadence is not in front. Move the existing store with SwiftData’s default migration behavior; do not invent a second copy of the tasks.
- Perform complete and add in the app process, writing `CadenceTask` and then pushing a new activity state. Completing does not open the app. Add opens the app only for the one-field fallback.
- On launch, and whenever tasks change, refresh every running list activity from the store with the batch rules. The batch ids live on the activity, so a relaunch does not invent a new batch.
- One activity per pinned scope. Pinning a list that is already running refreshes it.

## Testing

- Unit-test the resolver: first batch of three, a completed row stays, no backfill before the batch is done, advance only when every remaining row is crossed out, the final struck-through batch stays, a deleted row drops without backfill, a new task waits, a new task replaces a finished batch, a task that leaves the scope drops off.
- Build the app target and the extension with the project’s available Xcode scheme. A lock-screen pass on a device or simulator is manual; the tests do not claim to have tapped a real Live Activity.

## Left to the builder

- File names, type names, and how the extension is wired into `project.pbxproj`.
- The exact control symbol and the wording of the system title prompt and the fallback field, as long as each use asks, an empty title does nothing, and the fallback is only that one field.
- How the Tasks screen presents Standard and Transparent, as long as both exist, the choice is remembered, and it updates running activities.
- Signing: the App Group and the extension must be in the project entitlements. Installing on a device still depends on the Apple developer account having that group.
