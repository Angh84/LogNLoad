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

### Current Entry and Set

- Expanding the cover from the pinned bar keeps the current Entry and Set.
- When the cover opens after a relaunch: the first Entry with a target Set, on its first target Set. When no Entry has one, the last Entry, in its no-target state ([Set loop](#set-loop)). The current Entry and Set are never stored.
- Edit mode opens on the first Entry, on its first Set.
- When the current Entry is removed (from the overview sheet, by Remove Exercise or by a merge), the next Entry becomes current, else the previous one, else the [empty Workout](#empty-workout).
- When the current Set is deleted: in the Active Workout, the Entry's first target Set becomes current, else the card shows its no-target state; in edit mode, the following Set, else the previous one, else "No Sets".

### Empty Workout

- With no Exercise Entries, the pager keeps the list button and the "+" chip. The card and the Sets log are replaced by "Add your first Exercise to start logging." with "Add Exercise", which opens the [Exercise picker](#exercise-picker).

### Card

Top to bottom:

- The Exercise name, with a "..." menu.
- The Exercise note, always shown when it has one.
- The Entry note, when it has one (added from the "..." menu).
- The current Set:
  - its title: "Set n of m", where n is its number among the Entry's Working Sets and m is how many Working Sets the Entry has; or "Warm-up" for a Warm-up Set;
  - a big weight stepper: 2.5 kg per tap, never below 0. Tapping the number lets the user type any value, stored to 2 decimals;
  - a big reps stepper, 1 per tap, never below 0. For a unilateral Exercise, a Left and a Right reps stepper;
  - a "Warm-up" chip that toggles `isWarmUp`, and a "Set note" chip that opens the Set note field. Turning "Warm-up" on clears the Set's RIR ([data-model.md](data-model.md#invariants));
  - on a Completed Working Set, an RIR chip that changes its RIR. A Warm-up Set has no RIR chip;
  - the primary action ([Set loop](#set-loop)).
- The steppers and chips work on a Completed Set as on a target. Changing its values keeps its `completedAt`.

### Sets log

- Under the card, a "Sets" header with "+ Add Set", in the Active Workout and in edit mode.
- Then every Set of the current Entry in order: its label (W for a Warm-up Set; Working Sets numbered 1..n), its values, its RIR and a tick when completed.
- Tapping a row makes that Set current.
- Swiping a row deletes the Set. Long-press and drag reorders.

### Exercise "..." menu

Exactly these items:

- "Add note" / "Edit note" (the Entry note)
- "Swap Exercise" (edit mode only)
- "Remove Exercise"

## Set loop

- The card opens on the Entry's first target Set.
- Current target Set: the primary action is "Complete Set".
  - Completing a Working Set shows the "Reps in reserve?" panel with 0, 1, 2, 3, Easy and Skip. Any choice (Skip leaves RIR empty) moves on to the next target Set.
  - Completing a Warm-up Set moves on to the next target Set at once, with no panel.
- Current Completed Set: "Undo completion" and "Next Set".
  - "Undo completion" makes it a target again ([workout-lifecycle.md](workout-lifecycle.md#sets)).
  - "Next Set" makes the Entry's first target Set current, or shows the no-target state when none is left.
- No-target state, when the Entry has no target Set left:
  - "All N Sets done", where N counts the Entry's Working Sets, or "All Sets done" when it has none; "No Sets" when the Entry has no Sets at all;
  - with "Add Set" and "Next: <Exercise>" (the next Entry). On the last Entry, "Add Exercise" replaces "Next: <Exercise>".
- "Add Set", here or in the Sets log header, follows [workout-lifecycle.md](workout-lifecycle.md#sets) and makes the new Set current.
- Normal iOS auto-lock applies during a Workout; the screen is not kept awake.

## Overview sheet

- Opened by the list button at the start of the pager.
- At the top, the Workout name and note fields. Then every Entry with its Set summary. At the bottom, "Discard Workout".
- Drag an Entry to reorder, swipe it to remove it ([Remove Exercise](#prompts)), tap it to jump to it.
- The same sheet is used in edit mode, where it ends after the Entries: no "Discard Workout" and nothing in its place.

## Exercise picker

- Opened by the "+" chip, or already up after "Start Workout".
- A search field, then the sections "In this Workout", "Recent" and "All Exercises" (A-Z).
- "Recent": up to 8 Exercises from finished Workouts, each once, ordered by the latest `startedAt` of a finished Workout that contains it. Exercises from the same Workout follow its Entry order. Exercises already in this Workout and Archived Exercises are left out before counting to 8. Hidden when empty.
- Every row shows the Exercise's Last Performance.
  - **Open** ([What do the open display formats and UI copy say?](https://github.com/Angh84/LogNLoad/issues/21)): the row's format.
- Archived Exercises are not offered.
- An Exercise already in the Workout is tagged "In Workout". Picking it switches to its chip, with the toast "<name> is already in this Workout".
- Picking any other Exercise appends its Entry ([workout-lifecycle.md](workout-lifecycle.md#adding-an-exercise)) and makes it current.
- When no Exercise's name matches the search exactly (the uniqueness rule in [data-model.md](data-model.md#invariants)), a `Create "<search text>"` row opens the [Exercise form](exercise-library-screens.md#exercise-form) with the name filled in ([navigation.md](navigation.md#exercise-form)). Saving adds the new Exercise with one empty target Set (0 kg x 0).
- When the search exactly matches an Archived Exercise's name, an "Unarchive <name>" row replaces the Create row. Tapping it unarchives the Exercise and adds it like any picked Exercise (Prefill in the Active Workout, the [edit session](workout-lifecycle.md#edit-session) rules in edit mode), then closes the picker onto its new Entry with the toast "<name> is back in the Library". The new form's "Unarchive it" does the same when the form came from the Create row ([exercise-library-screens.md](exercise-library-screens.md#fields)).

## Finish sheet

- "Finish" opens one sheet with:
  - the duration and time range; the Exercise count, counting Entries with at least one Completed Set; and the Set count, counting Completed Working Sets, with "+ N warm-up" when there are completed Warm-up Sets;
  - the warning "N target Sets not completed will be removed", when there are any;
  - the warning "<Exercises> have no completed Sets and will be removed", when there are any;
  - when the last Completed Set is more than 15 minutes old, the end-time choice "Last Set hh:mm" (the default) / "Now hh:mm";
  - "Finish Workout" and "Keep Logging".
- With zero Completed Sets, "Finish" instead shows the alert "Discard this Workout?" with "No Sets are completed, so there is nothing to save."
  - **Open** ([What do the open display formats and UI copy say?](https://github.com/Angh84/LogNLoad/issues/21)): the alert's buttons.

## Edit mode

- Nav bar: "Cancel" / "Editing Workout" / "Done", on a purple nav bar.
- A purple banner: an "Editing" tag with the Workout's date; Start and End as two compact date-and-time pickers (`DatePicker`, `.compact`); then the hint "Sets you add count as completed, with time unknown. Nothing is saved until you tap Done."
- Start and End are edited independently: changing Start never moves End. They are checked on Done ([Prompts](#prompts)).
- The Workout name and note live in the overview sheet.
- No "Complete Set" buttons. A Set's status reads "Completed hh:mm", or "Completed, time unknown" when `completedAt` is empty.
- The card's actions are "Add Set" and "Next Set" (the following Set). On the Entry's last Set, "Next: <Exercise>" replaces "Next Set", or "Add Exercise" on the last Entry.
- Sets and Exercises added in edit mode follow [workout-lifecycle.md](workout-lifecycle.md#edit-session).
- "Swap Exercise" in the Exercise "..." menu opens the picker with only [Compatible Exercises](data-model.md#derived-never-stored) (in "Recent" too), no Create row, no Unarchive row, and the same sections and search.

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

- In the Discard Workout message, N counts the Completed Sets, Warm-up Sets included. With no Completed Sets, it reads "This deletes the Workout. Nothing is saved to history or Health."
- **Open** ([What do the open display formats and UI copy say?](https://github.com/Angh84/LogNLoad/issues/21)): the stale message when no target Set is left, and the "N ago" format.
- `<Workout>` in the overlap title is the Workout title ([history-screens.md](history-screens.md#workout-title)).

## Edge cases

- Creating an Exercise from the picker in edit mode: it is added with one Set, completed, time unknown, not a target.
- Removing, from the overview sheet, an Entry whose Sets are all targets: removed at once, no prompt.
- In edit mode every Set is completed, so removing any Entry with Sets asks first.
- Completing the last target Set of the last Entry: after the RIR panel (none for a Warm-up Set), the card shows "All N Sets done" with "Add Set" and "Add Exercise".
- Undoing a completion in the "All N Sets done" state's Entry makes that Set a target again, so the card returns to the Set loop on it.

Sources: [How does the logging screen flow?](https://github.com/Angh84/LogNLoad/issues/12), [What does a Set record beyond reps and weight?](https://github.com/Angh84/LogNLoad/issues/6), [How does a Workout start, finish, and survive interruption?](https://github.com/Angh84/LogNLoad/issues/7), [What can be edited after a Workout, and what happens to Exercises with history?](https://github.com/Angh84/LogNLoad/issues/11), [What is the app's navigation structure?](https://github.com/Angh84/LogNLoad/issues/13), [What do the logging and Library screens do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/20)
