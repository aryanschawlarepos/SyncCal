# Planner Tab Design

## Goal

Add a second top-level tab named Planner. The Planner shows the current day and its events in a time-based list while preserving Cadence's existing dark, amber-accented visual language.

## User Experience

- The app has two native tabs: Calendar and Planner.
- Calendar retains its existing month grid and selected-day agenda behavior.
- Planner opens on the current day, with the current date and weekday in its header.
- Timed events are shown in chronological order on a vertical timeline.
- All-day events are shown in a compact section above the timed timeline.
- Each event keeps its EventKit calendar color and displays its title, time range, and location when available.
- The existing add-event action remains available from Planner and creates events for the current day.
- Planner uses the same calendar visibility filters and event data as Calendar.

## Timeline Rules

- The default visible timeline starts at 8:00 AM.
- With no timed events, the visible timeline ends at 8:00 PM.
- When timed events exist, the timeline ends at the latest timed event's end time, whether that is before or after 8:00 PM.
- If a timed event starts before 8:00 AM, the timeline expands upward to include the event's start time.
- The timeline never renders unused hourly rows after the final task.
- With no timed events, Planner still presents the 8:00 AM-8:00 PM workday range and an empty-state message.
- Events that overlap the day are obtained through the existing `CalendarStore.events(on:)` query. All-day events do not affect timed timeline bounds.

## Architecture

- Introduce a shared root tab container after permission is granted.
- Keep `CalendarHomeView` responsible for the existing Calendar tab.
- Add a focused `PlannerView` that receives the existing `CalendarStore` and `NotificationManager` dependencies.
- Add small pure timeline-bound/layout helpers where practical so dynamic range rules can be unit tested without EventKit or view inspection.
- Reuse `EventRow` styles and `Theme` tokens where they fit, while using event tint for planner event blocks.

## Interaction and State

- Planner observes the same store instance as Calendar, so newly created or deleted events appear in both tabs after `reload()`.
- Planner is always anchored to today's date for this first version; no separate date navigation is required.
- Tapping the add button opens the existing editor with today's date as the initial date.
- Event deletion remains available through the existing event context-menu behavior.

## Testing

- Unit-test the timeline bounds for no timed events, events within the workday, late events, and early events.
- Unit-test that all-day events are excluded from timed bounds.
- Add a UI test that launches with access available, switches to Planner, and verifies the Planner tab and current-day content are visible.
- Run the full available test/build command for the Xcode project before completion.

## Out of Scope

- Date navigation inside Planner.
- Editing an event directly from a planner block.
- Changing workday hours from settings.
- New event storage or synchronization behavior.
