# History screens

The History list with its calendar, and the Workout detail screen. Editing and deleting rules: [workout-lifecycle.md](workout-lifecycle.md#finished-workouts). Navigation: [navigation.md](navigation.md).

Prototype: [history-screens.prototype.html](../../prototypes/history-screens/history-screens.prototype.html), winning variant **B (Calendar)** (`?variant=B`), reworked: the list is continuous rather than month by month, and the detail actions come from variant A. Visual reference only; this spec wins on any conflict.

## Counts

- Every Set count on these screens (rows, week headers, the month header, the detail's Sets tile) counts Working Sets only.
- Warm-up Sets appear only as "+ N warm-up" in the detail's Sets tile.

## Workout title

- A named Workout's title is its name.
- An unnamed Workout's title is its first two Exercise names, followed by "+N" when it has more (N = how many more).

## History list

- The root of the History tab: one continuous list of finished Workouts, newest `startedAt` first.
- The Active Workout is in neither the list nor the calendar; it lives only in the pinned bar.
- Sticky week sections, Monday to Sunday, headed "This week", "Last week", then the date range ("14 - 20 Sep"), each with "N Workouts, N Sets".
  - **Open** ([What do the open display formats and UI copy say?](https://github.com/Angh84/LogNLoad/issues/21)): the range when a week spans two months.
- A row: a date block (weekday and day of month), the [Workout title](#workout-title), and "17:30, 70 min - 5 Exercises, 14 Sets" (start time, duration, Exercise count, Set count).
  - **Open** ([What do the open display formats and UI copy say?](https://github.com/Angh84/LogNLoad/issues/21)): the duration format here and on the other screens.
- Tapping a row pushes its [Workout detail](#workout-detail).
- Swiping a row deletes the Workout, behind the [Delete Workout confirm](#workout-detail).
- Empty state, with no calendar: "No Workouts yet. Tap Start Workout to log your first one."

### Finish landing

- After Finish: the list at the top, the month grid expanded, the new Workout's row briefly highlighted.

## Calendar

- A month grid above the list, with a header naming the month and its counts.
  - **Open** ([What do the open display formats and UI copy say?](https://github.com/Angh84/LogNLoad/issues/21)): the month header's exact content.
- Days with Workouts show one dot per Workout. Today is ringed. Future days are faint. Days without Workouts can't be tapped.
- On scroll, the grid collapses into a pinned one-week strip (M-S, with dots) that follows the list. Tapping the strip expands the month.
- If the strip is too costly to build, the fallback is a grid that scrolls away as the list's header.
- The grid and the list always agree:
  - tapping a day scrolls the list to that day's first Workout in the list;
  - paging the month (arrows or swipe) scrolls the list to that month's newest Workout, or to the nearest older one when the month has none;
  - the next-month arrow stops at the current month;
  - the strip has no swipe of its own.

## Workout detail

- Pushed in the current tab's stack. Nav bar: back ("< History" from the list) and "Edit" on the right.
- While an Active Workout exists, Edit is disabled and a banner at the top reads "Finish or discard your current Workout to edit."
- Title: the Workout's name; for an unnamed Workout, its date, with the Exercise names as a subtitle.
- Tiles: Duration (with the start and end times), Exercises, Sets (with "+ N warm-up" when there are any).
- The Workout note, under the tiles.
- Exercises: one collapsed row per Entry, with a compact Set summary ("W 30 kg x 10 / 62.5 kg x 10, 9, 8") and a note icon when the Entry or any of its Sets has a note.
  - **Open** ([What do the open display formats and UI copy say?](https://github.com/Angh84/LogNLoad/issues/21)): how the compact summary groups Sets, and how unilateral, Bodyweight and Assisted Sets are written.
- Tapping an Exercise row only expands it: its Sets with W / 1..n labels, RIR and Set notes, then the Entry note, then "Exercise history >", which pushes its [Exercise page](exercise-library-screens.md#exercise-page).
- "Expand all" / "Collapse all". Expanded state is not remembered.
- At the bottom, a red "Delete Workout" row. Its confirm: "Delete this Workout?" with "It's removed from history and from Health. This can't be undone." Cancel / Delete. After Delete, the detail closes (back to History, or to the Exercise page it was opened from), with the toast "Workout deleted".
- Not shown: Health write status, Muscle Group volume, the previous time per Exercise.

## Edge cases

- Deleting from the detail while an Active Workout exists works; only Edit is blocked.
- A Workout edited to an earlier `startedAt` moves to its new week and day in the list and the calendar.
- A Workout whose Sets are all Warm-up Sets counts 0 Sets in its row, its week header and the month header; its detail's Sets tile shows 0 with "+ N warm-up".
- A Workout detail opened from an Exercise page in the Exercises tab has the same Edit and Delete Workout rules.
- Finishing a Workout with a backdated end ("Last Set") still lands with the new Workout at the top: no finished Workout can start after the Active Workout started.

Sources: [How do the Workout history screens look?](https://github.com/Angh84/LogNLoad/issues/14), [What is the app's navigation structure?](https://github.com/Angh84/LogNLoad/issues/13), [How does a Workout start, finish, and survive interruption?](https://github.com/Angh84/LogNLoad/issues/7), [What can be edited after a Workout, and what happens to Exercises with history?](https://github.com/Angh84/LogNLoad/issues/11), [How do the Exercise Library screens look?](https://github.com/Angh84/LogNLoad/issues/16)
