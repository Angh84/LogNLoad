# Data model

Every stored entity with its attributes, relationships and invariants, plus what is derived and never stored. Terms: [CONTEXT.md](../../CONTEXT.md).

## Storage

- Pure SwiftData. No Core Data stack alongside it, no GRDB.
- The model is CloudKit-safe, so iCloud sync can be switched on later ([ADR-0001](../adr/0001-cloudkit-safe-swiftdata-model.md)):
  - every stored attribute is optional or has a default value;
  - every relationship is optional and has an inverse;
  - no `@Attribute(.unique)` and no `#Unique`: uniqueness is enforced in app code;
  - no `.deny` delete rule;
  - order is an explicit `order` attribute, never the order of a to-many relationship.
- Entity names, attribute names and types are permanent: once CloudKit's production schema exists it can only be added to.
- The Swift type names are the entity names: `Workout`, `ExerciseEntry`, `WorkoutSet`, `Exercise`, `SeedRecord`, `PendingHealthDelete`.
- A `VersionedSchema` (`SchemaV1`) and a `SchemaMigrationPlan` exist from the first build.
- Every entity has `id: UUID` and `version: Int = 1`.
- The store uses the default `ModelConfiguration`: no custom store URL, no App Group in v1.
- Views read with `@Query`. Counts, Last Performance and other derived values are computed in memory; there are no aggregate fetches.
- `#Index` on Workout `startedAt` (History, Last Performance and "most recent" all order by it) and on Exercise Entry `exercise`.

In the tables, "optional, always set" means the store allows empty because of the CloudKit rules, but the app never saves the record without a value.

## Entities

### Workout

| Attribute | Type | Store | Rule |
|---|---|---|---|
| `id` | UUID | default new UUID | Also the Health sync identifier ([healthkit.md](healthkit.md#write-on-finish)) |
| `version` | Int | default 1 | |
| `startedAt` | Date | optional, always set | Tap time of "Start Workout". Editable on a finished Workout |
| `endedAt` | Date | optional | Empty = Active Workout. Set on Finish. Editable on a finished Workout |
| `name` | String | optional | Free text, editable any time |
| `note` | String | optional | Free text, editable any time |
| `healthWriteCounter` | Int | default 1 | Sync version of the next Health write. +1 each time a changed start or end time is saved |
| `healthConfirmedVersion` | Int | optional | The counter value Health last confirmed. Empty until the first write succeeds |
| `entries` | [Exercise Entry] | relationship | Sorted by Exercise Entry `order` |

### Exercise Entry

| Attribute | Type | Store | Rule |
|---|---|---|---|
| `id` | UUID | default new UUID | |
| `version` | Int | default 1 | |
| `order` | Int | default 0 | Position within its Workout |
| `note` | String | optional | Free text |
| `workout` | Workout | optional, always set | |
| `exercise` | Exercise | optional, always set | |
| `sets` | [Set] | relationship | Sorted by Set `order` |

### Set

The type and entity name is `WorkoutSet`, since `Set` collides with Swift's `Set`. The UI and this spec still say Set.

| Attribute | Type | Store | Rule |
|---|---|---|---|
| `id` | UUID | default new UUID | |
| `version` | Int | default 1 | |
| `order` | Int | default 0 | Position within its Exercise Entry |
| `weight` | Double | default 0 | kg, at least 0, 2 decimals. Per implement for Dumbbell and Kettlebell Exercises, the total for all other equipment. Read by Load Type: Loaded = the load lifted; Bodyweight = added load, 0 = bodyweight only; Assisted = assistance, higher is easier |
| `reps` | Int | default 0 | At least 0 (a failed attempt is 0). Used when the Exercise is not unilateral |
| `repsLeft` | Int | default 0 | At least 0. Used when the Exercise is unilateral |
| `repsRight` | Int | default 0 | At least 0. Used when the Exercise is unilateral |
| `rir` | Int | optional | 0, 1, 2, 3 or 4, where 4 = "Easy" (4 or more in reserve). Empty = not given. Unilateral: the weaker side |
| `isWarmUp` | Bool | default false | |
| `note` | String | optional | Free text |
| `completedAt` | Date | optional | Set to the tap time on completion. In the Active Workout, empty = target. In a finished Workout, empty = time unknown. There is no separate completed flag |
| `entry` | Exercise Entry | optional, always set | |

### Exercise

| Attribute | Type | Store | Rule |
|---|---|---|---|
| `id` | UUID | default new UUID | A seeded Exercise uses its fixed seed UUID. Changes only when a custom Exercise is adopted as a seed ([starter-library.md](starter-library.md#seeding-lifecycle)) |
| `version` | Int | default 1 | |
| `name` | String | optional, always set | Required. Unique (see [Invariants](#invariants)) |
| `equipment` | enum: Barbell, Dumbbell, Kettlebell, Machine, Cable, Band, Bodyweight, Other | optional, always set | |
| `loadType` | enum: Loaded, Bodyweight, Assisted | default Loaded | |
| `isUnilateral` | Bool | default false | Left and right reps are logged separately |
| `note` | String | optional | One free-text note, editable any time, shown while logging (e.g. machine settings) |
| `isArchived` | Bool | default false | |
| `muscleEmphases` | [Muscle Emphasis] | `.codable`, default empty, always one or more | A value list in [stored order](#muscle-emphasis) |
| `entries` | [Exercise Entry] | relationship | |

Weight is kg app-wide; there is no per-Exercise unit. Body weight is not stored.

### Muscle Emphasis

A Codable value stored inside Exercise `muscleEmphases`, not an entity ([ADR-0004](../adr/0004-muscle-emphases-value-list.md)).

| Field | Type | Rule |
|---|---|---|
| `muscleGroup` | Muscle Group | Stored by its raw key |
| `weight` | Double | 0.0 to 1.0, 2 decimals |

- A Muscle Group appears at most once per Exercise.
- `.codable` is opaque to predicates and sorting, so everything that reads Muscle Emphases does it in memory.
- A change to the value's shape triggers no migration: a field added later is optional or decodes with a default.
- Stored order:
  - a seed takes the order of its source entry ([starter-library.md](starter-library.md#seeds));
  - the Exercise form appends a newly added Muscle Group at the end;
  - changing a weight keeps its place; removing a Muscle Group and adding it again puts it at the end.

### Muscle Group and Body Area

A fixed list of 22 Muscle Groups, each in one Body Area. Not user-editable; new Muscle Groups ship in an app update. Each has a stable raw key, its name in camelCase (`upperChest`, `frontDelts`, `lowerBack`), which is what records store and which never changes when a display name does. In list order:

| Body Area | Muscle Groups |
|---|---|
| Chest | Upper Chest, Lower Chest |
| Shoulders | Front Delts, Side Delts, Rear Delts, Rotator Cuff |
| Back | Lats, Upper Back, Traps, Lower Back |
| Arms | Biceps, Brachialis, Triceps, Forearms |
| Core | Abs, Obliques |
| Legs | Quads, Hamstrings, Glutes, Adductors, Abductors, Calves |

Body Area is a display grouping only and is not stored on any record.

### Seed record

One per seed UUID ever applied. It outlives its Exercise.

| Attribute | Type | Store | Rule |
|---|---|---|---|
| `id` | UUID | default new UUID | Set to the seed's fixed UUID |
| `version` | Int | default 1 | |
| `fingerprint` | String | optional, always set | Fingerprint of the source entry last applied ([starter-library.md](starter-library.md#seeding-lifecycle)) |

### Pending Health delete

A tombstone for a Health delete not yet done ([healthkit.md](healthkit.md#deletes)).

| Attribute | Type | Store | Rule |
|---|---|---|---|
| `id` | UUID | default new UUID | |
| `version` | Int | default 1 | |
| `workoutId` | UUID | optional, always set | The deleted Workout's `id` |

## Relationships

| Relationship | Inverse | Delete rule |
|---|---|---|
| Workout `entries` (to-many) | Exercise Entry `workout` | Cascade: deleting a Workout deletes its Entries |
| Exercise Entry `sets` (to-many) | Set `entry` | Cascade: deleting an Entry deletes its Sets |
| Exercise `entries` (to-many) | Exercise Entry `exercise` | Nullify. Never reached: an Exercise with Entries is archived, not deleted, and merge moves its Entries before deleting it |

Seed record and Pending Health delete have no relationships.

## Invariants

- At most one Workout has an empty `endedAt`: the Active Workout.
- A Workout has at most one Exercise Entry per Exercise.
- A finished Workout's `endedAt` is after its `startedAt` and not in the future.
- Workouts never overlap. Two Workouts overlap when each starts before the other ends; the Active Workout ends now.
- A finished Workout has at least one Exercise Entry, each of its Entries has at least one Set, and each of its Sets is a Completed Set.
- Exercise names are unique ignoring case, Archived Exercises included, compared as stored.
- Exercise and Workout names and every note (Workout, Exercise Entry, Set, Exercise) are stored trimmed of leading and trailing whitespace and newlines. Inner spacing is kept as typed. Empty after trimming is stored as no value.
- An Exercise with history never changes `loadType` or `isUnilateral`, and changes `equipment` only within its weight convention.
- An Exercise with history is never hard-deleted, except by merge after its Entries have moved.
- An Exercise in the Active Workout is never archived.
- An Archived Exercise is never added to a Workout, as a new Entry, a swap target or a merge target.
- Editing a Set's values never changes its `completedAt`.
- A Warm-up Set never has an `rir`. Marking a Set as a Warm-up Set clears it, and marking it a Working Set again leaves it empty.
- A Seed record is never deleted.

## Derived, never stored

- **Active Workout**: the Workout with an empty `endedAt`.
- **Duration**: `endedAt - startedAt`. There is no pause.
- **Weight convention**: per implement for Dumbbell and Kettlebell; total for every other equipment.
- **Compatible Exercise** (swap and merge): a different, non-archived Exercise with the same `loadType`, the same `isUnilateral` and the same weight convention.
- **History** of an Exercise: it has an Exercise Entry in any Workout, the Active Workout included. "In N Workouts" counts those Workouts.
- **Last Performance**: the Sets of the Exercise's Entry in the finished Workout with the latest `startedAt` that contains it, in order. None when no finished Workout contains it. Recomputed on every read, so edits, swaps, merges, time changes and deletes apply at once. The Active Workout never counts.
- **Working Set**: a Set with `isWarmUp` false.
- **Top Muscle Group**: the Muscle Group of the Exercise's highest Muscle Emphasis weight. On a tie, the first in [stored order](#muscle-emphasis) wins (Deadlift: Glutes).
- **Muscle Emphasis display order**: highest weight first, ties in stored order.
- **Body Area placement**: the Body Area of the Top Muscle Group (Deadlift: Legs).
- **Seed**: an Exercise whose `id` has a Seed record.
- **Health pending**: a finished Workout whose `healthConfirmedVersion` differs from its `healthWriteCounter`.

## Room left for later

Later add-ons the v1 model must not block, and what v1 does now for each:

| Later | v1 |
|---|---|
| iCloud sync, Apple Watch | UUID on every record; the CloudKit-safe rules above |
| Workout suggestions (Muscle Group priority, what and when to train, a weight-loss goal from step counts) | Every Exercise carries Muscle Emphases. Priorities and goals become new entities later. Step counts are read from HealthKit on demand, never stored |
| PRs, progress charts | Nothing stored: derived from Completed Sets |
| Rest times | `completedAt` on every Completed Set |
| Recovery signal | Optional `rir` on every Completed Set |
| Cardio | Nothing now. Later: standalone cardio Workouts, with Workout gaining an activity kind that defaults to strength |
| Soreness check-in, sleep | Nothing now; additive later |
| Target-hit % in generated Workouts | Nothing now. Later: optional target fields on Set, by an additive migration |
| Duration-measured Exercises | Nothing now. Later: an Exercise measure type (Reps / Duration, default Reps) and an optional Set duration |
| Tonnage across Exercises | Nothing now. Later: an implement count |
| Total load of Bodyweight Exercises | Nothing now. Later: derived from HealthKit `bodyMass` history |

Sources: [Which future features must the v1 data model leave room for?](https://github.com/Angh84/LogNLoad/issues/2), [Is SwiftData ready, and what does later CloudKit sync constrain?](https://github.com/Angh84/LogNLoad/issues/3), [What does an Exercise record?](https://github.com/Angh84/LogNLoad/issues/5), [What does a Set record beyond reps and weight?](https://github.com/Angh84/LogNLoad/issues/6), [How does a Workout start, finish, and survive interruption?](https://github.com/Angh84/LogNLoad/issues/7), [Which storage stack and minimum iOS version?](https://github.com/Angh84/LogNLoad/issues/8), [What goes in the starter Exercise Library?](https://github.com/Angh84/LogNLoad/issues/9), [What does a finished Workout write to Health, and how do edits sync?](https://github.com/Angh84/LogNLoad/issues/10), [What can be edited after a Workout, and what happens to Exercises with history?](https://github.com/Angh84/LogNLoad/issues/11), [How do the Workout history screens look?](https://github.com/Angh84/LogNLoad/issues/14), [How do the Exercise Library screens look?](https://github.com/Angh84/LogNLoad/issues/16), [What does the data layer do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/19), [What do the logging and Library screens do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/20)
