# Exercise Library screens

The Library list, the Archived list, the Exercise page, the Exercise form, and the archive, delete, unarchive and merge flows, with the Exercise rules behind them. Stored fields and locks: [data-model.md](data-model.md#exercise). Navigation: [navigation.md](navigation.md).

Prototype: [exercise-library.prototype.html](../../prototypes/exercise-library/exercise-library.prototype.html), winning variant **B (Exercise page)** (`?variant=B`), reworked: the Archived row and the form-bottom actions come from variant A, the Muscle Group chip cloud from variant C. The prototype breaks Muscle Emphasis ties by the fixed Muscle Group order, which this spec does not ([data-model.md](data-model.md#derived-never-stored)). Visual reference only; this spec wins on any conflict.

## Exercise rules

- Always editable, and retroactive: name, Muscle Emphases, note. History shows the new name, since Entries reference the Exercise by `id`.
- A rename keeps the uniqueness rule ([data-model.md](data-model.md#invariants)).
- With history ([data-model.md](data-model.md#derived-never-stored)): Load Type and unilateral are locked, and equipment can change only within its weight convention.
- A wrong name or equipment on an Exercise with history is fixed by editing it, or by creating the right Exercise and swapping or merging. A wrong Load Type or unilateral flag is fixed by creating the right Exercise, logging that from now on, and archiving the old one, whose history stays with it. Nothing converts logged Sets.
- Delete: an Exercise without history is hard-deleted. An Exercise with history can only be archived.
- An Archived Exercise is hidden from the Library and the Exercise picker, still named in history, and keeps its name reserved.
- Archived Exercises are unarchived before they are edited or merged.
- An Exercise in the Active Workout can't be archived.
- Seeded Exercises follow the same rules as custom ones. A deleted seed never comes back ([starter-library.md](starter-library.md#seeding-lifecycle)).

## Library list

- The root of the Exercises tab. Large title "Exercises", with "+" opening the new [Exercise form](#exercise-form).
- One section per Body Area (Chest, Shoulders, Back, Arms, Core, Legs), in that order, headed with its count. A-Z inside each. Empty sections are hidden.
- An Exercise sits in the section of its [Body Area placement](data-model.md#derived-never-stored).
- Archived Exercises are not listed.
- A row: the name; then its Last Performance from Working Sets only ("28 Sep: 62.5 kg x 10, 9, 8"), or "Not logged yet"; and a small green dot while it is in the Active Workout.
  - **Open** ([What do the open display formats and UI copy say?](https://github.com/Angh84/LogNLoad/issues/21)): the row when Last Performance has only Warm-up Sets.
- Tapping a row opens its [Exercise page](#exercise-page). Rows have no swipe actions.
- At the bottom: an "Archived N >" row (hidden when there are none), then "N Exercises".

### Search

- Searches names only, across sections. Sections without hits are hidden.
- When no Exercise's name matches exactly (the uniqueness rule), a `Create "<text>"` row at the top opens the new form with the name filled in.
- When the text exactly matches an Archived Exercise's name: an "X is archived - In N Workouts" row with "Unarchive", which unarchives it in place with the toast "X is back in the Library".
- No hits: "No Exercises match".

### Archived list

- Opened by the "Archived N >" row. A-Z; each row reads "In N Workouts". Tapping a row opens its Exercise page.

## Exercise page

- Nav bar: back, and "Edit" on the right (pushes the edit form). No "..." menu. An Archived Exercise's page has no Edit.
- An Archived Exercise's page starts with the banner "Archived. It's hidden from the Library and the Exercise picker." with "Unarchive" (no confirm).
- Header: the name, then "Machine - Loaded - Unilateral - kg per dumbbell", showing only the parts that apply ("Unilateral" only when unilateral, "kg per dumbbell" or "kg per kettlebell" only for that equipment).
- An "In your current Workout" pill while it is in the Active Workout.
- The Exercise note.
- A Muscle Groups card: one bar per Muscle Emphasis, in [display order](data-model.md#derived-never-stored), each with its weight.
- Tiles: Workouts (finished Workouts only), Last (date), First (date).
- History: its finished Workouts, newest first, in month sections. A row: a date block, the [Workout title](history-screens.md#workout-title), and a compact Set summary including Warm-up Sets ("W 30 kg x 10 / 62.5 kg x 10, 9, 8"). The Active Workout is not listed. RIR and Set notes stay on the Workout detail.
- Tapping a history row pushes that Workout's [detail](history-screens.md#workout-detail), with its Edit and Delete Workout rules.
- Empty history: "Not in a finished Workout yet. Its Sets show up here once you finish one."

## Exercise form

One form for new and existing Exercises: the Library's "+", Edit on an Exercise page, and the picker's Create row ([navigation.md](navigation.md#exercise-form)).

### Nav and saving

- Nav bar: Back, "New Exercise" or "Edit Exercise", Save.
- Save is enabled only when the form is valid and changed.
- Back with unsaved changes: "Discard your changes?" Keep Editing / Discard.
- A new Exercise needs a name, equipment and at least one Muscle Group. Until then the hint reads "Add a name, equipment and at least one Muscle Group to save."
- New form defaults: no equipment, Loaded, not unilateral.
- Saving a new Exercise from the Library opens its new Exercise page. Saving an edit returns to the page. Saving from the picker's Create row adds it to the Workout ([logging-screen.md](logging-screen.md#exercise-picker)).

### Fields

- Name, with inline errors: "You already have an Exercise called X." / "X is archived." On a new form the archived error adds "Unarchive it".
- "Unarchive it" unarchives the Exercise with the toast "X is back in the Library" and drops what the form holds, with no prompt. From the Library, the form is replaced by the Exercise's page. From the picker's Create row, it also adds the Exercise to the Workout and closes the sheet onto its new Entry, as the picker's Unarchive row does ([logging-screen.md](logging-screen.md#exercise-picker)).
- Muscle Groups: a chip cloud of all 22 Muscle Groups in Body Area rows. Tapping a chip adds it at 1.0, last in [stored order](data-model.md#muscle-emphasis). Tapping an added chip shows an inline 0.25 / 0.5 / 0.75 / 1.0 control with "Remove". A seed weight off that scale (e.g. 0.9) shows as it is until changed. Footer: "Each weight is how much one Set counts toward that Muscle Group: 1.0 is a full Set, 0.5 is half a Set."
- Equipment: a 4 x 2 chip grid of the 8 options. When equipment is locked, the options across the weight convention are dimmed. For Dumbbell the footer reads "Weight is logged per dumbbell."; for Kettlebell, "Weight is logged per kettlebell."
- Load Type: a 3-way segmented control with one line of help: Loaded "Weight is the load you lift.", Bodyweight "Weight is added load. 0 kg is bodyweight only.", Assisted "Weight is assistance, so a higher number is easier."
- Unilateral: a toggle, footer "Left and right reps are logged separately."
- Lock note, when the Exercise has history: "It's in N Workouts, so Load Type and Unilateral are locked", plus the equipment limit, plus "Changing them would change what the logged Sets mean. If one is wrong, create a new Exercise and archive this one."
- Note, footer "Shown while you log this Exercise."

### Bottom actions (edit form only)

- "Merge into Another Exercise", when it has history.
- Then "Archive Exercise" when it has history, or "Delete Exercise" when it has none.
- While the Exercise is in the Active Workout, Archive is disabled with "It's in your current Workout, so it can't be archived yet." Merge stays available.

## Archive, delete, unarchive

| Action | Confirm | After |
|---|---|---|
| Archive | "Archive X?" with "It's in N Workouts, so it stays in your history. It's hidden from the Library and the Exercise picker until you unarchive it." Cancel / Archive | Back to the Library, toast "X archived" |
| Delete | "Delete X?" with "It isn't in any Workout, so it's deleted for good." For a seed, plus "Starter Exercises you delete don't come back." Cancel / Delete | Back to the Library, toast "X deleted" |
| Unarchive | None. From the page banner, a Library search hit, the new form's "Unarchive it", or the picker's "Unarchive <name>" row | From a Library search hit: unarchived in place, toast "X is back in the Library". From the new form: [Fields](#fields). From the picker: [logging-screen.md](logging-screen.md#exercise-picker) |

## Merge

Merging X into Y, from X's edit form:

- The sheet "Merge X into..." with "Pick the Exercise to keep. The Sets in N Workouts move to it, then X is deleted." and a search field.
- It lists only [Compatible Exercises](data-model.md#derived-never-stored): "Also mainly <X's Top Muscle Group>" first, then the rest. A footer names the filter and how many Exercises it hides.
- Confirm: "Move N Workouts from X to Y and delete X?", plus "N Workouts already have Y, so the Sets are combined there." when some Workouts hold both, plus "This can't be undone." Cancel (back to the sheet) / Merge.
- Merging moves every Entry of X, the Active Workout's included, to Y, [combining](workout-lifecycle.md#combining-entries) where a Workout holds both, then hard-deletes X. Irreversible.
- After: Y's Exercise page, with the toast "Merged into Y". Unsaved form edits on X are dropped.

## Edge cases

- An Exercise created from the picker is in the Active Workout at once, so it has history: its Load Type and unilateral are locked until its Entry is removed or it is otherwise out of every Workout.
- An Exercise whose only Entry was in the Active Workout and was dropped on Finish has no history again: its form offers Delete, not Archive.
- Searching the Library for an Archived Exercise's name shows the archived row, never a Create row, because the name stays reserved.
- Merging X, which is in the Active Workout, into Y: the Active Workout's Entry for X becomes Y's, target Sets included. Prefill already copied is untouched.
- Renaming a seed in the app lasts only until its source entry changes ([starter-library.md](starter-library.md#seeding-lifecycle)).

Sources: [How do the Exercise Library screens look?](https://github.com/Angh84/LogNLoad/issues/16), [What does an Exercise record?](https://github.com/Angh84/LogNLoad/issues/5), [What can be edited after a Workout, and what happens to Exercises with history?](https://github.com/Angh84/LogNLoad/issues/11), [What goes in the starter Exercise Library?](https://github.com/Angh84/LogNLoad/issues/9), [What is the app's navigation structure?](https://github.com/Angh84/LogNLoad/issues/13), [What do the logging and Library screens do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/20)
