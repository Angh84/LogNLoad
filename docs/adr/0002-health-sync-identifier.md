# Health sync identifier is the Workout UUID; only start/end edits rewrite

HealthKit objects are immutable, so an edited Workout can only reach Health by replacing its workout. Each Health workout carries `HKMetadataKeySyncIdentifier` = the Workout's UUID and `HKMetadataKeySyncVersion` = a per-Workout write counter, so saving again with a higher version replaces the old workout in one transaction-safe step, with delete-then-save as the fallback. The Health workout holds only start, end and duration (no Sets, reps or energy), so only a start or end change bumps the counter and rewrites; name, note and Set edits never touch Health. Replacing by sync identifier avoids the duplicate workouts a plain re-save would leave.

## Consequences

- The Workout's `id` must never change, or its Health workout is orphaned.
- The counter and the last confirmed version live on the Workout; when they differ the write is pending and is retried on launch and foreground.
- A workout the user deletes in Health is written again only if that Workout's times are edited.

Sources: [What does a finished Workout write to Health, and how do edits sync?](https://github.com/Angh84/LogNLoad/issues/10), [What can a HealthKit strength workout carry, and what needs a paid account?](https://github.com/Angh84/LogNLoad/issues/4), [research](../research/healthkit-strength.md)
