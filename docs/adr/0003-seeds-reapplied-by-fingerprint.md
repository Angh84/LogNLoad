# Seeds re-applied from source by fingerprint

The starter Exercise Library lives in source, and the user adds and changes seeds there, so source changes must reach an installed app without undoing what the user did in the app. On every launch the app compares each source seed with a stored Seed record (seed UUID + fingerprint of the entry last applied): a new UUID is inserted, a changed fingerprint overwrites the seed's name, Muscle Emphases, equipment, Load Type and unilateral flag, and an unchanged one is left alone. The Seed record outlives its Exercise, so a seed the user deletes or merges away is never inserted again. The fixed seed UUIDs also give a later CloudKit sync a key to dedupe seeds across devices.

## Consequences

- An in-app edit to a seed lasts until its source entry changes, then the source wins for the overwritten fields.
- Notes and the archived flag are never touched by source.
- Fields locked by history (Load Type, unilateral, equipment across the weight convention) and colliding renames are skipped when overwriting. The fingerprint still moves to the new entry, so skipped parts are dropped rather than retried; retrying would re-apply the whole entry on every launch and wipe in-app edits.
- A new seed whose name matches a custom Exercise adopts it: the custom Exercise's `id` changes to the seed UUID and the source entry is applied over it. It is the only case where an Exercise's `id` changes.

Sources: [What goes in the starter Exercise Library?](https://github.com/Angh84/LogNLoad/issues/9), [Is SwiftData ready, and what does later CloudKit sync constrain?](https://github.com/Angh84/LogNLoad/issues/3), [What does the data layer do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/19)
