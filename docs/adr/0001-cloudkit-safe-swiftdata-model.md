# SwiftData with CloudKit-safe model rules

v1 stores everything in pure SwiftData on the device with no sync, but the model already follows the rules SwiftData's CloudKit sync imposes: every attribute optional or defaulted, every relationship optional with an inverse, no `@Attribute(.unique)` or `#Unique` (uniqueness and UUID dedupe live in app code), no `.deny` delete rule, and explicit `order` fields instead of relying on to-many order. Sync underneath is `NSPersistentCloudKitContainer`, whose production schema is additive only, so the v1 model is shaped now as if its names and types are permanent, and iCloud sync or an Apple Watch app can be switched on later without reshaping it.

## Consequences

- Required values are enforced by the app, not the store; the store accepts empty values.
- Exercise names are unique by app check, and seeded Exercises carry fixed UUIDs so a later sync can dedupe them.
- Entity and attribute names are treated as permanent from v1, and every entity carries `version: Int = 1` so a later breaking change can filter by version.
- A `VersionedSchema` exists from the first build.

Sources: [Is SwiftData ready, and what does later CloudKit sync constrain?](https://github.com/Angh84/LogNLoad/issues/3), [Which storage stack and minimum iOS version?](https://github.com/Angh84/LogNLoad/issues/8), [research](../research/swiftdata-cloudkit.md)
