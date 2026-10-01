# LogNLoad v1 spec

LogNLoad is a personal, local-first iPhone app for logging strength Workouts. This folder is its build-ready v1 spec: the data model, storage, HealthKit, editing and the logging flow, written for Claude Code build sessions, with the user reviewing.

## Reading this spec

- A build session loads this README, [data-model.md](data-model.md) and the area file for its step in the [build order](#build-order). It follows links when a rule lives in another file.
- Each rule lives in exactly one file. Other files link to it rather than restate it.
- Domain terms (Workout, Active Workout, Exercise, Exercise Library, Archived Exercise, Exercise Entry, Set, Completed Set, Warm-up Set, Working Set, Last Performance, Prefill, RIR, Muscle Group, Body Area, Muscle Emphasis, Load Type) are defined in [CONTEXT.md](../../CONTEXT.md) and never redefined here.
- UI copy is quoted exactly. In copy, `N`, `X`, `Y`, `<name>`, `<Exercise>`, `<Exercises>`, `<Workout>`, `<date>` and `hh:mm` are placeholders; a noun after a count is singular when the count is 1 ("1 Set", "2 Sets").
- **Open** marks a point still being decided on the map, linked to its ticket. Don't build a guess for it: build around it, or wait for the answer.
- Prototypes are visual reference only. This spec wins on any conflict.

## Scope

- One user, one iPhone. Apple Watch comes later.
- Native Swift and SwiftUI. Local-first on the device: no backend, no accounts, no sign-in.
- Freeform Workouts, started empty and built up as you go.
- A custom Exercise Library, seeded with a starter list.
- Prefill from Last Performance, with each target Set confirmed as it is performed.
- Sets added and removed mid-Workout.
- Workout history, with editing and delete.
- Finished Workouts written to Apple Health.
- Strength training only. The data model leaves room for later add-ons without building them ([data-model.md](data-model.md#room-left-for-later)).

## Out of scope

- Routines and templates (future Workout suggestions replace them)
- Workout suggestions from Muscle Group priority, goals and step counts (v1 only tags Exercises with Muscle Emphases)
- Daily soreness check-in, and sleep from HealthKit
- Rest timer
- PRs and estimated 1RM
- Progress charts
- Export and backup files
- iCloud sync (v1 must not block it: [ADR-0001](../adr/0001-cloudkit-safe-swiftdata-model.md))
- Cardio and other non-strength activity logging
- Any backend or server
- Importing data from the old LogNLoad app
- Duration- or distance-measured Exercises (planks, hangs, carries)

## Platform

- Minimum iOS: iOS 27.
- Storage: pure SwiftData ([data-model.md](data-model.md#storage)).
- Signing: the free Personal Team, which includes HealthKit. Its provisioning profile expires after 7 days: rebuild and reinstall. No App Store, no TestFlight.

## Files

| File | Covers |
|---|---|
| [data-model.md](data-model.md) | Entities, attributes, relationships, invariants, derived values, storage rules |
| [workout-lifecycle.md](workout-lifecycle.md) | Starting, logging, finishing, discarding and interrupted Workouts; editing and deleting finished Workouts |
| [healthkit.md](healthkit.md) | Permission, the Health write on Finish, edit and delete sync, retries |
| [navigation.md](navigation.md) | Tabs, the pinned Workout bar, launch, the logging cover, onboarding, where each screen is pushed |
| [logging-screen.md](logging-screen.md) | The Focus logging screen, Exercise picker, overview sheet, Finish sheet, edit mode, logging prompts |
| [history-screens.md](history-screens.md) | History list, calendar, Workout detail |
| [exercise-library-screens.md](exercise-library-screens.md) | Library list, Exercise page, Exercise form, archive, delete and merge |
| [starter-library.md](starter-library.md) | The 74 seed Exercises and the seeding lifecycle |

Architecture decisions: [ADR-0001](../adr/0001-cloudkit-safe-swiftdata-model.md) (CloudKit-safe SwiftData model), [ADR-0002](../adr/0002-health-sync-identifier.md) (Health sync identifier), [ADR-0003](../adr/0003-seeds-reapplied-by-fingerprint.md) (seeds re-applied by fingerprint), [ADR-0004](../adr/0004-muscle-emphases-value-list.md) (Muscle Emphases as a value list).

Background research: [SwiftData and CloudKit](../research/swiftdata-cloudkit.md), [HealthKit strength workouts](../research/healthkit-strength.md).

Prototypes (visual reference only): [logging screen](../../prototypes/logging-screen/logging-flow.prototype.html), [history screens](../../prototypes/history-screens/history-screens.prototype.html), [Exercise Library](../../prototypes/exercise-library/exercise-library.prototype.html). Open in a browser; `?variant=A|B|C` picks a layout.

## Build order

| Step | Build | Area files |
|---|---|---|
| 1 | Data layer: models, `VersionedSchema`, invariants, seeding lifecycle, Last Performance query. Tested, no UI. | [data-model.md](data-model.md), [starter-library.md](starter-library.md) |
| 2 | App shell: two tabs, the Start Workout / Active Workout bar, the Health onboarding screen (its permission request is wired in step 7). | [navigation.md](navigation.md) |
| 3 | Logging: Focus screen, picker with Prefill and Create, overview sheet, Finish sheet, interruption and stale prompts. The first version usable at the gym. | [logging-screen.md](logging-screen.md), [workout-lifecycle.md](workout-lifecycle.md) |
| 4 | History: month grid / week strip list and Workout detail, read-only. | [history-screens.md](history-screens.md) |
| 5 | Editing and delete of finished Workouts: Focus in edit mode, Swap, no overlaps. | [workout-lifecycle.md](workout-lifecycle.md#finished-workouts), [logging-screen.md](logging-screen.md#edit-mode) |
| 6 | Exercise Library: list, Exercise page, form, archive, merge. | [exercise-library-screens.md](exercise-library-screens.md) |
| 7 | HealthKit: write on Finish, sync-identifier replace on edit, delete with tombstone, retry. The first retry pass writes the Workouts finished before this step. | [healthkit.md](healthkit.md) |

Turning this build order into build issues is the next effort after the spec map, not part of the spec.

## App-wide conventions

**Identity**
- Display name: "LogNLoad".
- Bundle identifier: `com.angh84.lognload`. Never change it after the first install: a new identifier is a new app, which leaves the SwiftData store behind and can no longer replace or delete the Health workouts written earlier.
- Icon: a placeholder made in Icon Composer, one white glyph (a dumbbell or a plate) on a dark background, with the default, dark and tinted variants. The final icon doesn't block the build.

**Device and orientation**
- iPhone only. No iPad layout.
- Portrait only.

**Language and formats**
- English UI only. Strings are written in code; no localization in v1.
- Dates, times, numbers and the first weekday follow the device's Region setting, through `FormatStyle`. A Swedish region shows 24-hour times, weeks starting Monday and "62,5 kg".
- Weight input accepts the Region's decimal separator.
- Weight is always in kg, whatever the Region ([data-model.md](data-model.md#set)).
- Format examples in this spec ("17:30", "14 - 20 Sep", "62.5 kg", the M-S week strip) show one Region's output, not fixed formats.

**Appearance**
- Dark only, forced app-wide (`UIUserInterfaceStyle` = `Dark` in Info.plist). No light mode and no override.
- System semantic colors, plus one app accent color for primary actions (Complete, Start Workout, Finish) and selection (chips, week-strip dots). The hue is chosen during the build. It must meet WCAG AA contrast (4.5:1) for text on the accent and for the accent on the dark backgrounds.
- Launch screen: a plain black background, no logo (`UILaunchScreen` in Info.plist).

**Text and accessibility**
- System text styles everywhere, so Dynamic Type scales all text.
- Layouts stay usable up to the largest standard size (xxxLarge). The accessibility sizes (AX1 to AX5) get no layouts of their own: text still scales, wrapping and truncation are acceptable, and nothing is clipped away.
- VoiceOver: SwiftUI's defaults only, and it isn't tested. Every icon-only button (chevron, note icon, stepper + and -, menus) has an accessibility label.
- Reduce Motion: no special handling.

**Feedback**
- Haptics through `.sensoryFeedback`: `.success` on Complete Set and on Finish, `.selection` on each weight or reps stepper tap. No other custom haptics and no in-app toggle.
- No sounds.

**Health permission revoked later**
- Handled exactly like Don't Allow at onboarding: nothing is shown anywhere.
- Writes stay pending and deletes keep their Pending Health delete. Once sharing is turned back on in Health's settings, the [retry](healthkit.md#retry) writes and deletes all of them. Nothing pending is ever dropped.

Settled in other files: the minimum iOS ([Platform](#platform)), normal auto-lock during a Workout ([logging-screen.md](logging-screen.md#set-loop)), no Settings screen ([navigation.md](navigation.md#tabs)).

## Open

Points the assembly found undecided. Each is marked **Open** where it applies.

- [What do the open display formats and UI copy say?](https://github.com/Angh84/LogNLoad/issues/21)

## Lifecycle of this spec

- Spec first until v1 ships: when a decision changes during the build, edit it into the spec before the code.
- When v1 ships, this README is marked "Frozen at v1". From then on the code, [CONTEXT.md](../../CONTEXT.md) and the ADRs are the truth, and later features get their own map.
- [starter-library.md](starter-library.md) holds the initial seed content. Once the seed source exists in code, that source wins.

Sources: [LogNLoad v1 spec](https://github.com/Angh84/LogNLoad/issues/1), [What shape does the v1 spec take, and where does it live?](https://github.com/Angh84/LogNLoad/issues/15), [Which storage stack and minimum iOS version?](https://github.com/Angh84/LogNLoad/issues/8), [What can a HealthKit strength workout carry, and what needs a paid account?](https://github.com/Angh84/LogNLoad/issues/4), [Which future features must the v1 data model leave room for?](https://github.com/Angh84/LogNLoad/issues/2), [What app-wide conventions does v1 follow?](https://github.com/Angh84/LogNLoad/issues/17), [What does the data layer do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/19)
