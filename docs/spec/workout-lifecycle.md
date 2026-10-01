# Workout lifecycle

How a Workout starts, is logged, finishes or is discarded, survives interruption, and is edited or deleted once finished. Screens and copy: [logging-screen.md](logging-screen.md). Health effects: [healthkit.md](healthkit.md). Terms: [CONTEXT.md](../../CONTEXT.md).

## Active Workout

### Start

- "Start Workout" creates a Workout with `startedAt` = the tap time, at once, with no confirm.
- While an Active Workout exists, no other Workout can start.

### Persistence

- The Active Workout is an ordinary stored Workout with an empty `endedAt`.
- Every change is saved at once, target Sets included, so the Workout survives an app kill and a phone restart.

### Adding an Exercise

- A new Exercise Entry is appended after the last one.
- Adding an Exercise that already has an Entry in the Workout creates nothing; the logging screen goes to the existing Entry.
- Prefill: when the Exercise has a Last Performance, the new Entry gets one target Set per Set of Last Performance, in the same order, copying `weight`, `reps`, `repsLeft`, `repsRight` and `isWarmUp`. 0-rep Sets and Warm-up Sets are copied like any other. `rir`, Set notes and the Entry note are not copied.
- With no Last Performance, the new Entry gets one target Set of 0 kg x 0 reps.
- Prefill is a snapshot: later edits to history don't change Sets already copied.

### Sets

- Completing a Set sets `completedAt` to the tap time and keeps the values it has. The Set is edited in place, so no target values remain.
- Undoing a completion clears `completedAt`. The values stay and the Set is a target again. No confirm.
- Add Set appends a target Working Set with the `weight`, `reps`, `repsLeft` and `repsRight` of the Entry's last Working Set. With no Working Set, it copies the Entry's last Set, as a Working Set. With no Sets, it is 0 kg x 0 reps.
- Until Finish, Sets and Entries can be added, removed, reordered and edited at any time.

### Finish

- The end time is the tap time of "Finish", unless the last Completed Set's `completedAt` is more than 15 minutes before the tap. Then the user picks the last Completed Set's time (the default) or now.
- Finishing drops every target Set, then every Exercise Entry left with no Sets, its note included, then sets `endedAt`.
- A Workout with zero Completed Sets can't be finished. Finish offers to discard it instead.
- Finishing writes the Workout to Health ([healthkit.md](healthkit.md#write-on-finish)).

### Discard

- Discard is available at any time during the Active Workout, behind a confirm.
- Discard hard-deletes the Workout, its Entries and its Sets. Nothing reaches history or Health.

### Stale Workout

- When the app launches or returns from the background with an Active Workout whose last activity is more than 3 hours ago, it asks to finish at the last Completed Set, resume, or discard.
- Last activity is the latest of the last `completedAt`, `startedAt` and the last Resume tap on this prompt. The Resume tap is kept in memory only, never stored, so a relaunch soon after Resume asks again.
- Finishing from the stale prompt uses the last Completed Set's `completedAt` as the end time and the [Finish](#finish) rules.
- With zero Completed Sets the choices are resume or discard.

## Finished Workouts

### Edit session

- A finished Workout is edited in an edit session. Done saves every change at once; Cancel discards every change.
- Run each edit session in its own `ModelContext`, so Cancel's rollback can't discard live Active Workout changes.
- A finished Workout can't be edited while an Active Workout exists. It can still be deleted.
- An edit session can do everything the Active Workout allows (add, remove, reorder and edit Sets and Entries; Entry notes; Workout name and note), and also change `startedAt` and `endedAt` and swap an Entry's Exercise.
- A Set added while editing is a Completed Set with an empty `completedAt` (time unknown).
- An Exercise added while editing gets one Set of 0 kg x 0 reps, completed, time unknown. No Prefill.
- Changing the start or end time leaves every Set's `completedAt` as it is.

### Swap

- Swap changes an Entry's Exercise to a [Compatible Exercise](data-model.md#derived-never-stored). The Entry keeps its Sets and note.
- Swapping to an Exercise that already has an Entry in the Workout [combines the Entries](#combining-entries).

### Combining Entries

Swap and merge combine when Entry X's Exercise becomes Exercise Y and the same Workout already has an Entry Y:

- One Entry remains, for Y, at the earlier of the two positions.
- Its Sets are Y's Sets followed by X's Sets, each keeping their order.
- Its note is Y's note and X's note joined with a newline. An empty note adds nothing.

### Done

- Done saves only when:
  - `endedAt` is after `startedAt` and not in the future;
  - the Workout overlaps no other Workout;
  - at least one Set remains. When none does, Done offers to delete the Workout instead.
- Saving drops every Entry left with zero Sets, its note included.
- When the start or end time changed, saving rewrites the Health workout once ([healthkit.md](healthkit.md#edits)).

### Delete

- Delete Workout hard-deletes the Workout, its Entries and its Sets. No trash, no undo.
- It also deletes the Health workout ([healthkit.md](healthkit.md#deletes)).
- Deleting is allowed while an Active Workout exists.

## Edge cases

- Undoing the only completion in the Active Workout, then tapping Finish: there are zero Completed Sets, so Finish offers to discard.
- An Entry whose Sets were all completed, then all un-completed, is dropped on Finish along with its note.
- A Prefilled Exercise whose Last Performance Workout is then deleted or edited keeps the Sets it copied.
- Resuming a stale Workout, then leaving the app in the background for more than 3 more hours without completing a Set: the prompt asks again on return.
- Resuming a stale Workout and then tapping Finish: the last Completed Set is more than 15 minutes old, so the end-time choice appears with the last Set's time as the default.
- Moving a finished Workout's start later than some Sets' `completedAt`, or its end earlier: allowed. Those Sets keep times outside the Workout.
- Editing a finished Workout's `startedAt` can change which Workout is "most recent" for an Exercise, and with it that Exercise's Last Performance.
- Removing every Set while editing, then Done: the Workout is deleted, from Health too.
- Merging Exercise X into Y while the Active Workout holds X: its Entry for X becomes Y's, target Sets included, combined if it also holds Y ([exercise-library-screens.md](exercise-library-screens.md#merge)).

Sources: [How does a Workout start, finish, and survive interruption?](https://github.com/Angh84/LogNLoad/issues/7), [What does a Set record beyond reps and weight?](https://github.com/Angh84/LogNLoad/issues/6), [What can be edited after a Workout, and what happens to Exercises with history?](https://github.com/Angh84/LogNLoad/issues/11), [How does the logging screen flow?](https://github.com/Angh84/LogNLoad/issues/12), [What is the app's navigation structure?](https://github.com/Angh84/LogNLoad/issues/13), [What do the logging and Library screens do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/20)
