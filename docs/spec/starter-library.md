# Starter library

The seed Exercises a new install starts with, how seeds are named and weighted, and how the app applies seed changes on launch. The "why" of the lifecycle: [ADR-0003](../adr/0003-seeds-reapplied-by-fingerprint.md).

This file holds the initial seed content. Once the seed source exists in code, that source wins for the seed table; the naming, weighting and lifecycle rules stay here.

## Selection

- The seeds are only Exercises the user actually does: every name in the user's StrengthLog export (113 Workouts, 2025-05-23 to 2026-09-25) plus the current training program, with duplicates and mislogs merged and brand variants split out. 74 seeds.
- Duration-measured Exercises are not seeded (Biceps Isometric Hold is out of scope).

## Naming

- The user's own phrasing, with "DB" for dumbbell.
- A machine's brand is a suffix in parentheses: "Chest Press (Hoist)". Every machine seed carries its brand.
- Every Nautilus machine is "(Nautilus)", whatever the product line.

## Muscle Emphasis weights

How seed weights are set, for adding or changing seeds:

- A weight is the fraction of one Set counted toward that Muscle Group's training volume; 1.0 is a full direct Set. Volume per Muscle Group = the sum of Sets x weight.
- Rotator Cuff only on active rotation work (external or internal rotation, face pull).
- No Forearms credit for grip, only for direct wrist work. Exception: Hammer Curl, Forearms 0.5 (brachioradialis).
- Grip and upper-arm position set the Biceps / Brachialis split.
- 0.9 instead of 1.0 where free-weight resistance vanishes at the bottom (DB lateral raise; EZ, concentration and hammer curls) or the stretch is limited (pushdowns, lying leg curl).
- Brand variants of one movement share weights.

## Seeds

Every seed has its own fixed UUID, generated once when the seed source is written and never changed. Every seed starts with an empty note and not archived. Muscle Emphases are stored in the order listed, which breaks weight ties ([data-model.md](data-model.md#muscle-emphasis)). The groups below organise this table only; the Library places each Exercise by its [Body Area placement](data-model.md#derived-never-stored).

### Chest

| Seed | Equipment | Load Type | Unilateral | Muscle Emphases |
|---|---|---|---|---|
| Incline Chest Press (Hoist) | Machine | Loaded | no | Upper Chest 1.0, Lower Chest 0.5, Front Delts 0.75, Triceps 0.5 |
| Incline Chest Press (Hammer Strength) | Machine | Loaded | no | Upper Chest 1.0, Lower Chest 0.5, Front Delts 0.75, Triceps 0.5 |
| Incline Chest Press (Nautilus) | Machine | Loaded | no | Upper Chest 1.0, Lower Chest 0.5, Front Delts 0.75, Triceps 0.5 |
| Chest Press (Hoist) | Machine | Loaded | no | Lower Chest 1.0, Upper Chest 0.5, Front Delts 0.5, Triceps 0.5 |
| Chest Press (Hammer Strength) | Machine | Loaded | no | Lower Chest 1.0, Upper Chest 0.5, Front Delts 0.5, Triceps 0.5 |
| Chest Press (Nautilus) | Machine | Loaded | no | Lower Chest 1.0, Upper Chest 0.5, Front Delts 0.5, Triceps 0.5 |
| Chest Press (Star Trac) | Machine | Loaded | no | Lower Chest 1.0, Upper Chest 0.5, Front Delts 0.5, Triceps 0.5 |
| Chest Fly (Nautilus) | Machine | Loaded | no | Lower Chest 1.0, Upper Chest 0.5, Front Delts 0.25 |

### Shoulders

| Seed | Equipment | Load Type | Unilateral | Muscle Emphases |
|---|---|---|---|---|
| Lateral Raise (Nautilus) | Machine | Loaded | no | Side Delts 1.0, Traps 0.25 |
| Seated DB Lateral Raise | Dumbbell | Loaded | no | Side Delts 0.9, Traps 0.25 |
| Single-Arm Cable Lateral Raise | Cable | Loaded | yes | Side Delts 1.0, Traps 0.25 |
| Shoulder Press (Hoist) | Machine | Loaded | no | Front Delts 1.0, Side Delts 0.5, Triceps 0.5, Upper Chest 0.25, Traps 0.25 |
| Shoulder Press (Hammer Strength) | Machine | Loaded | no | Front Delts 1.0, Side Delts 0.5, Triceps 0.5, Upper Chest 0.25, Traps 0.25 |
| Shoulder Press (Nautilus) | Machine | Loaded | no | Front Delts 1.0, Side Delts 0.5, Triceps 0.5, Upper Chest 0.25, Traps 0.25 |
| Shoulder Press (Star Trac) | Machine | Loaded | no | Front Delts 1.0, Side Delts 0.5, Triceps 0.5, Upper Chest 0.25, Traps 0.25 |
| Reverse Fly (Nautilus) | Machine | Loaded | no | Rear Delts 1.0, Upper Back 0.5 |
| Face Pull | Cable | Loaded | no | Rear Delts 1.0, Side Delts 0.5, Rotator Cuff 0.5, Upper Back 0.5, Traps 0.25 |
| Cable Upright Row | Cable | Loaded | no | Side Delts 1.0, Traps 0.75, Front Delts 0.25 |
| Barbell Upright Row | Barbell | Loaded | no | Side Delts 1.0, Traps 0.75, Front Delts 0.25 |
| Cable External Rotation at Side | Cable | Loaded | yes | Rotator Cuff 1.0, Rear Delts 0.25 |
| Cable Internal Rotation at Side | Cable | Loaded | yes | Rotator Cuff 1.0 |
| Prone Incline Y Raise | Dumbbell | Loaded | no | Upper Back 1.0, Side Delts 0.25, Rear Delts 0.25 |

### Back

| Seed | Equipment | Load Type | Unilateral | Muscle Emphases |
|---|---|---|---|---|
| Lat Pulldown (Hoist) | Machine | Loaded | no | Lats 1.0, Upper Back 0.5, Biceps 0.5, Brachialis 0.25, Rear Delts 0.25 |
| Lat Pulldown (Hammer Strength) | Machine | Loaded | no | Lats 1.0, Upper Back 0.5, Biceps 0.5, Brachialis 0.25, Rear Delts 0.25 |
| Lat Pulldown (Nautilus) | Machine | Loaded | no | Lats 1.0, Upper Back 0.5, Biceps 0.5, Brachialis 0.25, Rear Delts 0.25 |
| Lat Pulldown (Star Trac) | Machine | Loaded | no | Lats 1.0, Upper Back 0.5, Biceps 0.5, Brachialis 0.25, Rear Delts 0.25 |
| Cable Lat Pulldown | Cable | Loaded | no | Lats 1.0, Upper Back 0.5, Biceps 0.5, Brachialis 0.25, Rear Delts 0.25 |
| Lat Prayer | Cable | Loaded | no | Lats 1.0, Triceps 0.25 |
| Assisted Pull-Up (Nautilus) | Machine | Assisted | no | Lats 1.0, Upper Back 0.5, Biceps 0.5, Brachialis 0.5, Rear Delts 0.25 |
| High Row (Hammer Strength) | Machine | Loaded | no | Lats 0.75, Upper Back 0.75, Rear Delts 0.5, Biceps 0.5, Brachialis 0.25 |
| Seated Row (Hammer Strength) | Machine | Loaded | no | Upper Back 1.0, Lats 0.75, Rear Delts 0.5, Biceps 0.5, Brachialis 0.25 |
| Seated Row (Hoist) | Machine | Loaded | no | Upper Back 1.0, Lats 0.75, Rear Delts 0.5, Biceps 0.5, Brachialis 0.25 |
| Seated Row (Nautilus) | Machine | Loaded | no | Upper Back 1.0, Lats 0.75, Rear Delts 0.5, Biceps 0.5, Brachialis 0.25 |
| Seated Row (Star Trac) | Machine | Loaded | no | Upper Back 1.0, Lats 0.75, Rear Delts 0.5, Biceps 0.5, Brachialis 0.25 |
| Cable Close-Grip Seated Row | Cable | Loaded | no | Lats 1.0, Upper Back 0.75, Biceps 0.5, Brachialis 0.5, Rear Delts 0.25 |
| Cable Wide-Grip Seated Row | Cable | Loaded | no | Upper Back 1.0, Rear Delts 0.75, Lats 0.5, Brachialis 0.5, Biceps 0.25 |
| Barbell Row | Barbell | Loaded | no | Upper Back 1.0, Lats 0.75, Rear Delts 0.5, Lower Back 0.5, Biceps 0.5, Brachialis 0.25 |
| Pullover (Nautilus) | Machine | Loaded | no | Lats 1.0, Lower Chest 0.25, Triceps 0.25 |
| Back Extension (Nautilus) | Machine | Loaded | no | Lower Back 1.0, Glutes 0.25 |
| Deadlift | Barbell | Loaded | no | Glutes 0.75, Hamstrings 0.75, Lower Back 0.75, Quads 0.5, Traps 0.5, Adductors 0.25 |

### Biceps and forearms

| Seed | Equipment | Load Type | Unilateral | Muscle Emphases |
|---|---|---|---|---|
| Close-Grip EZ Preacher Curl | Barbell | Loaded | no | Biceps 1.0, Brachialis 0.75 |
| DB Preacher Curl | Dumbbell | Loaded | yes | Biceps 1.0, Brachialis 0.5 |
| Biceps Curl (Nautilus) | Machine | Loaded | no | Biceps 1.0, Brachialis 0.5 |
| Incline Biceps Curl (Nautilus) | Machine | Loaded | no | Biceps 1.0, Brachialis 0.25 |
| Lying DB Curl | Dumbbell | Loaded | no | Biceps 1.0, Brachialis 0.25 |
| Bayesian Curl | Cable | Loaded | yes | Biceps 1.0, Brachialis 0.25 |
| Cable Curl With Bar | Cable | Loaded | no | Biceps 1.0, Brachialis 0.5 |
| EZ Curl | Barbell | Loaded | no | Biceps 0.9, Brachialis 0.5 |
| Concentration Curl | Dumbbell | Loaded | yes | Biceps 0.9, Brachialis 0.5 |
| Hammer Curl | Dumbbell | Loaded | no | Brachialis 0.9, Biceps 0.5, Forearms 0.5 |
| DB Wrist Curl | Dumbbell | Loaded | no | Forearms 1.0 |
| DB Wrist Extension | Dumbbell | Loaded | no | Forearms 1.0 |

### Triceps

| Seed | Equipment | Load Type | Unilateral | Muscle Emphases |
|---|---|---|---|---|
| Triceps Pushdown With Bar | Cable | Loaded | no | Triceps 0.9 |
| Triceps Pushdown With Rope | Cable | Loaded | no | Triceps 0.9 |
| Seated DB French Press | Dumbbell | Loaded | no | Triceps 1.0 |
| Seated Single-Arm DB French Press | Dumbbell | Loaded | yes | Triceps 1.0 |
| Triceps Extension (Nautilus) | Machine | Loaded | no | Triceps 1.0 |
| Lying EZ Triceps Extension | Barbell | Loaded | no | Triceps 1.0 |
| Assisted Dip (Nautilus) | Machine | Assisted | no | Triceps 1.0, Lower Chest 0.75, Front Delts 0.5 |
| Dip Machine (Nautilus) | Machine | Loaded | no | Triceps 1.0, Lower Chest 0.5, Front Delts 0.25 |

### Legs

| Seed | Equipment | Load Type | Unilateral | Muscle Emphases |
|---|---|---|---|---|
| Leg Press (Hammer Strength) | Machine | Loaded | no | Quads 1.0, Glutes 0.5, Adductors 0.5 |
| Seated Leg Press (Nautilus) | Machine | Loaded | no | Quads 1.0, Glutes 0.5, Adductors 0.5 |
| Hack Squat (Hammer Strength) | Machine | Loaded | no | Quads 1.0, Glutes 0.5, Adductors 0.5 |
| Squat | Barbell | Loaded | no | Quads 1.0, Glutes 0.75, Adductors 0.5, Lower Back 0.25 |
| Air Squat | Bodyweight | Bodyweight | no | Quads 1.0, Glutes 0.75, Adductors 0.5 |
| DB Walking Lunge | Dumbbell | Loaded | yes | Quads 1.0, Glutes 0.75, Adductors 0.5 |
| Bodyweight Lunge | Bodyweight | Bodyweight | yes | Quads 1.0, Glutes 0.75, Adductors 0.5 |
| Leg Extension (Nautilus) | Machine | Loaded | no | Quads 1.0 |
| Seated Leg Curl (Nautilus) | Machine | Loaded | no | Hamstrings 1.0 |
| Lying Leg Curl (Nautilus) | Machine | Loaded | no | Hamstrings 0.9 |
| Romanian Deadlift | Barbell | Loaded | no | Hamstrings 1.0, Glutes 0.75, Adductors 0.5, Lower Back 0.5 |
| Hip Adduction (Nautilus) | Machine | Loaded | no | Adductors 1.0 |
| Hip Abduction (Nautilus) | Machine | Loaded | no | Abductors 1.0, Glutes 0.25 |
| Standing Calf Raise (Nautilus) | Machine | Loaded | no | Calves 1.0 |

## Seeding lifecycle

- The seed list lives in source; the user adds and changes seeds there.
- On every launch, the app compares each source seed with the [Seed record](data-model.md#seed-record) for its UUID:
  - no Seed record (never applied), and no Exercise has the seed's name (ignoring case): insert the Exercise and create the Seed record with the entry's fingerprint;
  - no Seed record, and a custom Exercise has the seed's name, archived or not: adopt it. It takes the seed's UUID as its `id` (its Entries reference it by relationship, so its history stays), the source entry is applied as an overwrite (below), its note and archived flag are kept, and the Seed record is created;
  - no Seed record, and another seed has the seed's name: skip, with no Seed record, so it is retried on every launch and inserted once the name is free;
  - a Seed record whose fingerprint differs from the source entry's: overwrite the Exercise's name, Muscle Emphases, equipment, Load Type and unilateral flag, and store the new fingerprint;
  - otherwise: nothing.
- Only a source change overwrites a seed: in-app edits to a seed last until its source entry changes.
- Source never touches a seed's note or archived flag.
- A seed deleted or merged away in the app stays gone: its Seed record remains, and there is no Exercise to overwrite.
- A seed removed from source leaves the store untouched.
- Skipped when overwriting a seed with history: Load Type, the unilateral flag, and an equipment change across the weight convention (the [lock](data-model.md#invariants)). Also skipped: a rename that collides with an existing name, Archived Exercises included.
- The stored fingerprint always moves to the entry just processed, even when part of it was skipped. Skipped parts are dropped; only a later change to the source entry tries them again.

## Edge cases

- Renaming a seed in the app, then changing its Muscle Emphases in source: the next launch also puts the source name back.
- A seed with history whose source entry changes its Load Type: the other fields are overwritten; the Load Type stays.
- Deleting a seed in the app, then editing its source entry: nothing is inserted, since its Seed record exists.
- Creating "Pec Deck (Hoist)" in the app, then adding it to source as a seed: the next launch adopts the custom Exercise as that seed, with its history and note.
- A seed with history whose source entry changes its Load Type and Muscle Emphases: the Muscle Emphases are overwritten, the Load Type is dropped, and the fingerprint moves, so later launches don't retry it.

Sources: [What goes in the starter Exercise Library?](https://github.com/Angh84/LogNLoad/issues/9), [What does an Exercise record?](https://github.com/Angh84/LogNLoad/issues/5), [What can be edited after a Workout, and what happens to Exercises with history?](https://github.com/Angh84/LogNLoad/issues/11), [Is SwiftData ready, and what does later CloudKit sync constrain?](https://github.com/Angh84/LogNLoad/issues/3), [What does the data layer do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/19)
