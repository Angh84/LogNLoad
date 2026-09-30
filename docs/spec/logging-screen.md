# Logging screen

The Focus logging screen used for the Active Workout and, in edit mode, for finished Workouts: its layout, the Set loop, the Exercise picker, the overview sheet, the Finish sheet and the logging prompts. Behavior behind it: [workout-lifecycle.md](workout-lifecycle.md). Where it opens: [navigation.md](navigation.md#logging-cover).

Prototype: [logging-flow.prototype.html](../../prototypes/logging-screen/logging-flow.prototype.html), winning variant **C (Focus)** (`?variant=C`). The prototype predates the overview sheet, the 2.5 kg stepper and the removal of the Workout "..." menu. Visual reference only; this spec wins on any conflict.

## Layout

### Nav bar

- Active Workout: the elapsed timer in the middle, "Finish" on the right. No "..." Workout menu.
- Edit mode: [see Edit mode](#edit-mode).

### Chip pager

- A horizontal pager across the top: a list button first (opens the [overview sheet](#overview-sheet)), then one chip per Exercise Entry in order, then a "+" chip (opens the [Exercise picker](#exercise-picker)).
- A chip shows the Exercise name and one progress bar per Set, filled when the Set is completed.
- Tapping a chip makes its Entry current.
- **Open** ([What do the logging and Library screens do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/20)): what the screen shows when the Workout has no Exercise Entries, and which Entry and Set are current when the cover opens.

### Card

Top to bottom:

- The Exercise name, with a "..." menu.
- The Exercise note, always shown when it has one.
- The Entry note, when it has one (added from the "..." menu).
- The current Set:
  - its title: "Set n of m", where n is its number among the Entry's Working Sets and m is how many Working Sets the Entry has; or "Warm-up" for a Warm-up Set;
  - a big weight stepper: 2.5 kg per tap, never below 0. Tapping the number lets the user type any value, stored to 2 decimals;
  - a big reps stepper, 1 per tap, never below 0. For a unilateral Exercise, a Left and a Right reps stepper;
  - a "Warm-up" chip that toggles `isWarmUp`, and a "Set note" chip that opens the Set note field;
  - the primary action ([Set loop](#set-loop)).

### Sets log

- Under the card, every Set of the current Entry in order: its label (W for a Warm-up Set; Working Sets numbered 1..n), its values, its RIR and a tick when completed.
- Tapping a row makes that Set current.
- Swiping a row deletes the Set. Long-press and drag reorders.

### Exercise "..." menu

Exactly these items:

- "Add note" / "Edit note" (the Entry note)
- "Swap Exercise" (edit mode only)
- "Remove Exercise"

## Set loop

- The card opens on the Entry's first target Set.
- Current target Set: the primary action is "Complete Set". Completing it shows the "Reps in reserve?" panel with 0, 1, 2, 3, Easy and Skip. Any choice (Skip leaves RIR empty) moves on to the next target Set.
  - **Open** ([What do the logging and Library screens do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/20)): whether the panel also follows completing a Warm-up Set.
- Current Completed Set: "Undo completion" makes it a target again ([workout-lifecycle.md](workout-lifecycle.md#sets)). Its RIR chip changes its RIR.
  - **Open** ([What do the logging and Library screens do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/20)): whether its weight and reps can be changed with the steppers without undoing the completion.
- No target Set left in the Entry: "All N Sets done", with "Add Set" and "Next: <Exercise>" (the next Entry). On the last Entry, "Add Exercise" replaces "Next: <Exercise>".
  - **Open** ([What do the logging and Library screens do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/20)): whether N counts all Sets or Working Sets, and where else "Add Set" is offered.
- "Add Set" follows [workout-lifecycle.md](workout-lifecycle.md#sets) and makes the new Set current.
- Normal iOS auto-lock applies during a Workout; the screen is not kept awake.

## Overview sheet

- Opened by the list button at the start of the pager.
- At the top, the Workout name and note fields. Then every Entry with its Set summary. At the bottom, "Discard Workout".
- Drag an Entry to reorder, swipe it to remove it ([Remove Exercise](#prompts)), tap it to jump to it.
- The same sheet is used in edit mode.
  - **Open** ([What do the logging and Library screens do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/20)): what replaces "Discard Workout" at its bottom in edit mode.

## Exercise picker

- Opened by the "+" chip, or already up after "Start Workout".
- A search field, then the sections "In this Workout", "Recent" (the last 8 Exercises from history) and "All Exercises" (A-Z).
  - **Open** ([What do the logging and Library screens do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/20)): exactly which Exercises "Recent" holds.
- Every row shows the Exercise's Last Performance.
  - **Open** ([What do the open display formats and UI copy say?](https://github.com/Angh84/LogNLoad/issues/21)): the row's format.
- Archived Exercises are not offered.
- An Exercise already in the Workout is tagged "In Workout". Picking it switches to its chip, with the toast "<name> is already in this Workout".
- Picking any other Exercise appends its Entry ([workout-lifecycle.md](workout-lifecycle.md#adding-an-exercise)) and makes it current.
- When no Exercise's name matches the search exactly (the uniqueness rule in [data-model.md](data-model.md#invariants)), a `Create "<search text>"` row opens the [Exercise form](exercise-library-screens.md#exercise-form) with the name filled in ([navigation.md](navigation.md#exercise-form)). Saving adds the new Exercise with one empty target Set (0 kg x 0).
- When the search exactly matches an Archived Exercise's name, an "Unarchive <name>" row replaces the Create row.
  - **Open** ([What do the logging and Library screens do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/20)): whether tapping it also adds the Exercise to the Workout.

## Finish sheet

- "Finish" opens one sheet with:
  - the duration and time range, and the Exercise and Set counts;
    - **Open** ([What do the logging and Library screens do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/20)): which Sets the count includes;
  - the warning "N target Sets not completed will be removed", when there are any;
  - the warning "<Exercises> have no completed Sets and will be removed", when there are any;
  - when the last Completed Set is more than 15 minutes old, the end-time choice "Last Set hh:mm" (the default) / "Now hh:mm";
  - "Finish Workout" and "Keep Logging".
- With zero Completed Sets, "Finish" instead shows the alert "Discard this Workout?" with "No Sets are completed, so there is nothing to save."
  - **Open** ([What do the open display formats and UI copy say?](https://github.com/Angh84/LogNLoad/issues/21)): the alert's buttons.

## Edit mode

- Nav bar: "Cancel" / "Editing Workout" / "Done", on a purple nav bar.
- A purple banner with the Workout's start and end times.
  - **Open** ([What do the logging and Library screens do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/20)): how the times are edited from it.
- The Workout name and note live in the overview sheet.
- No "Complete Set" buttons. A Set's status reads "Completed hh:mm", or "Completed, time unknown" when `completedAt` is empty.
- Sets and Exercises added in edit mode follow [workout-lifecycle.md](workout-lifecycle.md#edit-session).
- "Swap Exercise" in the Exercise "..." menu opens the picker with only [Compatible Exercises](data-model.md#derived-never-stored), no Create row, and the same sections and search.

## Prompts

| When | Title | Message | Buttons |
|---|---|---|---|
| Discard Workout | "Discard Workout?" | "This deletes the Workout and its N Sets. Nothing is saved to history or Health." | Cancel / Discard |
| Stale Workout on reopen ([rule](workout-lifecycle.md#stale-workout)) | "Workout still open" | "Your last Set was at hh:mm, N ago. Finishing removes N target Sets not completed." | "Finish at hh:mm" / Resume / Discard (Discard leads to the Discard Workout confirm) |
| Stale Workout, zero Completed Sets | "Workout still open" | **Open** ([What do the open display formats and UI copy say?](https://github.com/Angh84/LogNLoad/issues/21)) | Resume / Discard |
| Remove Exercise, only when the Entry has Completed Sets (otherwise it is removed at once) | "Remove <name>?" | "Its N completed Sets will be deleted." | **Open** ([What do the open display formats and UI copy say?](https://github.com/Angh84/LogNLoad/issues/21)) |
| Edit mode Cancel, only when something changed | "Discard your changes?" | none | Keep Editing / Discard |
| Edit mode Done, overlap | "Overlaps <Workout>" | "That Workout ran <date>, hh:mm to hh:mm. Change the start or end time so they don't overlap." | OK |
| Edit mode Done, invalid times | "Can't save these times" | The reason: the end isn't after the start, or the end is in the future. **Open** ([What do the open display formats and UI copy say?](https://github.com/Angh84/LogNLoad/issues/21)): the reason's wording | OK |
| Edit mode Done, zero Sets | "Delete this Workout?" | "You removed every Set, so saving would leave an empty Workout. It is deleted instead, from history and from Health." | Keep Editing / Delete |
| Swap into an Exercise already in the Workout | "Combine with <Y>?" | "<Y> is already in this Workout. Its Entry keeps the earlier position, the Sets from <X> are added after its own, and the notes are joined." | Cancel / Combine |

- **Open** ([What do the logging and Library screens do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/20)): which Sets "its N Sets" counts in the Discard Workout message.
- **Open** ([What do the open display formats and UI copy say?](https://github.com/Angh84/LogNLoad/issues/21)): the stale message when no target Set is left, and the "N ago" format.
- `<Workout>` in the overlap title is the Workout title ([history-screens.md](history-screens.md#workout-title)).

## Edge cases

- Creating an Exercise from the picker in edit mode: it is added with one Set, completed, time unknown, not a target.
- Removing, from the overview sheet, an Entry whose Sets are all targets: removed at once, no prompt.
- In edit mode every Set is completed, so removing any Entry with Sets asks first.
- Completing the last target Set of the last Entry: after the RIR panel, the card shows "All N Sets done" with "Add Set" and "Add Exercise".
- Undoing a completion in the "All N Sets done" state's Entry makes that Set a target again, so the card returns to the Set loop on it.

Sources: [How does the logging screen flow?](https://github.com/Angh84/LogNLoad/issues/12), [What does a Set record beyond reps and weight?](https://github.com/Angh84/LogNLoad/issues/6), [How does a Workout start, finish, and survive interruption?](https://github.com/Angh84/LogNLoad/issues/7), [What can be edited after a Workout, and what happens to Exercises with history?](https://github.com/Angh84/LogNLoad/issues/11), [What is the app's navigation structure?](https://github.com/Angh84/LogNLoad/issues/13)
