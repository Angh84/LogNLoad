# HealthKit

What a finished Workout writes to Apple Health, when permission is asked, how edits and deletes reach Health, and how failures retry. The "why" of the sync identifier: [ADR-0002](../adr/0002-health-sync-identifier.md). Background: [HealthKit strength workouts](../research/healthkit-strength.md).

## Setup

- The HealthKit capability (entitlement `com.apple.developer.healthkit`). The free Personal Team supports it.
- `NSHealthUpdateUsageDescription` in Info.plist: "LogNLoad saves your finished Workouts to Health as strength training, with their start and end times. It doesn't read anything from Health."
- No read permissions: the app never reads from Health.

## Permission

- Share permission for `HKObjectType.workoutType()` only.
- Requested when the user taps Continue on the onboarding screen ([navigation.md](navigation.md#onboarding)). The system sheet's Don't Allow is the opt-out.
- An install that finished onboarding before HealthKit was built was never asked: it is asked on its next launch, before the retry pass. HealthKit shows the sheet only while the request was never made, so every install sees it once.
- No in-app toggle. Health's per-app switch is the control.

## Write on Finish

- On Finish, an unattached `HKWorkoutBuilder` (`init(healthStore:configuration:device:)`, no `HKWorkoutSession`) saves one workout:
  - activity type `.traditionalStrengthTraining`;
  - `beginCollection` at the Workout's `startedAt`, `endCollection` at its `endedAt`, as stored (a backdated "Last Set" end included), then `finishWorkout`;
  - metadata: `HKMetadataKeySyncIdentifier` = the Workout's `id` as a string, `HKMetadataKeySyncVersion` = its `healthWriteCounter`, `HKMetadataKeyIndoorWorkout` = true. Nothing else.
- No samples (no active energy, no heart rate), no workout events, no pause events.
- A discarded Workout writes nothing. The Active Workout is never written.
- A successful write sets `healthConfirmedVersion` to the `healthWriteCounter` it wrote.

## Edits

- Only a saved change to `startedAt` or `endedAt` reaches Health: it adds 1 to `healthWriteCounter`, which makes the Workout pending, and writes it once.
- Name, note, Entry and Set edits never touch Health.
- A rewrite saves the workout again with the same sync identifier and the new, higher sync version, which replaces the old one.
- Fallback: delete the app's workouts matching the sync identifier, then save.
- Which of the two is used is settled by the first on-device check below.

## Deletes

- Deleting a Workout in the app deletes the Health workouts the app saved with that Workout's sync identifier.
- A [Pending Health delete](data-model.md#pending-health-delete) keeping the Workout's `id` is saved with the Workout's delete, and removed once the Health delete succeeds. A failure leaves it for retry.
- A workout the user deletes in Health is left alone; the app doesn't observe Health deletions. It comes back only if that Workout's times are edited, since the rewrite saves it again.

## Retry

- On every launch and every return to the foreground, the app silently retries every pending Workout ([data-model.md](data-model.md#derived-never-stored)) and every Pending Health delete.
- The same pass backfills after a late permission grant, and writes the Workouts finished before HealthKit was built.
- Failures show nothing. No screen shows a Health write status.

## First-build on-device checks

- A sync-identifier replace leaves exactly one workout in Health. If not, switch rewrites to the fallback.
- After the Personal Team's 7-day re-sign and reinstall, the app can still replace and delete workouts it saved earlier.
- In the iOS 27 simulator, a replace left exactly one live workout and marked the older version deleted, so rewrites replace. Deleting the Workout left none, and a delete that matched nothing succeeded. Neither check above has run on the iPhone yet.

## Edge cases

- Finishing with "Last Set" as the end time writes that earlier time; Health never sees the Finish tap time.
- Editing only the name of a Workout the user deleted in Health: it stays deleted there. Editing its times: it is written again.
- Deleting a Workout whose first write never succeeded: the delete finds nothing in Health, which counts as done.
- A time edit saved while permission is denied: the Workout stays pending and is written after a later grant.

Sources: [What can a HealthKit strength workout carry, and what needs a paid account?](https://github.com/Angh84/LogNLoad/issues/4), [What does a finished Workout write to Health, and how do edits sync?](https://github.com/Angh84/LogNLoad/issues/10), [What can be edited after a Workout, and what happens to Exercises with history?](https://github.com/Angh84/LogNLoad/issues/11), [What is the app's navigation structure?](https://github.com/Angh84/LogNLoad/issues/13), [What do the open display formats and UI copy say?](https://github.com/Angh84/LogNLoad/issues/21), [When does an install already past onboarding get asked for Health permission?](https://github.com/Angh84/LogNLoad/issues/41)
