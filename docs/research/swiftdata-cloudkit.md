# SwiftData readiness and CloudKit-later constraints

Research for issue #3. Question: how mature is SwiftData for a local-first app with a few entities (Workout, Exercise, Set; thousands of Sets over years), what are its limitations vs Core Data or GRDB, and what does enabling SwiftData + CloudKit sync later constrain in the v1 model today?

Researched 2026-09-28 against Apple primary sources (docs, WWDC transcripts, release notes, Apple-badged forum replies). GRDB facts come from its own repository. Items marked **[uncertain]** could not be confirmed from a primary source.

## Summary

- SwiftData is in its fourth year: it shipped in iOS 17 and has added features every June since - indexes, `#Unique` and history in iOS 18; model inheritance in iOS 26; `ResultsObserver`, `HistoryObserver`, `.codable` attributes and sectioned queries in iOS 27 [1][2][3]. The iOS 27 docs are no longer marked beta [3].
- For this size (a few entity types, thousands of rows), Apple engineers' advice at WWDC26 for large datasets comes down to indexing (`#Index`), using fetch limits, and keeping predicates inside the query [4]. Thousands of Sets is not a dataset size Apple singles out as a concern **[uncertain - no Apple benchmark found]**.
- Known gaps vs Core Data: no aggregate fetches (min/max via `NSExpression`) - Apple suggests using Core Data side by side on the same store for those [4][5]. Before iOS 27 there was no non-SwiftUI observer (no `NSFetchedResultsController` equivalent), and `@Query` had a known bug where it did not refresh after CloudKit sync [6][3]. GRDB (v7.11.1, June 2026) gives direct SQL, `DatabaseMigrator` and `ValueObservation`, but has no built-in CloudKit sync [7].
- SwiftData's CloudKit sync is `NSPersistentCloudKitContainer` underneath, so the Core Data + CloudKit model rules apply [8][9].
- CloudKit-later rules the v1 model must follow today: every attribute optional or given a default value [10]; every relationship optional and with an inverse [9][11]; no `@Attribute(.unique)` or `#Unique` [8][9]; no `.deny` delete rule [9]; no dependence on to-many order [12].
- After the CloudKit schema is promoted to production it is additive only: record types and fields cannot be renamed, deleted or changed [8][9]. Plan the v1 names and types as if they are permanent.
- Model uniqueness in app logic (a `UUID` field and dedupe code) instead of store constraints. Apple's Core Data sample dedupes by UUID, and names seeded starter data as a known source of duplicates across devices - this applies directly to the Exercise Library starter list [13][14].
- Use `VersionedSchema` + `SchemaMigrationPlan` from v1. Apple engineers say you can version the current schema at any time, but must test migrating from every shipped version [4][15].

## Maturity

- **Release history.** SwiftData first shipped in iOS 17 [16]. Apple's SwiftData updates page lists yearly feature drops [1]:
  - June 2024 (iOS 18): `#Index`, `#Unique`, `inverse: nil` unidirectional relationships, `fetchHistory`/`deleteHistory`, custom `DataStore`.
  - June 2025 (iOS 26): model inheritance, and `sortBy` on `HistoryDescriptor`.
  - June 2026 (iOS 27): `sectionBy` queries, the `.codable` attribute option, `ResultsObserver`, `HistoryObserver`.
- **API availability checked in the docs:** `VersionedSchema` iOS 17.0; `#Unique` and `#Index` iOS 18.0; `ResultsObserver`, `HistoryObserver` and `.codable` iOS 27.0, not marked beta [17][18][19][3].
- **Bug history.** The iOS 17 release notes have a long list of fixed SwiftData issues, including default values not initializing, stale `@Query`, and `#Predicate` not supporting UUID/Date/URL [20]. The iOS 27 release notes list one fixed SwiftData issue: a `@Query` deadlock when saving on a background actor (178113288) [3].
- **Sync-related bug.** An Apple DTS engineer called "a known bug that has been there for a while" the case where relationship changes arriving via CloudKit do not refresh `@Query`-driven views (iOS 18, FB14619787). The suggested workaround was observing `.NSPersistentStoreRemoteChange` [6]. Whether this is fixed **[uncertain]**. iOS 27's `ResultsObserver` is documented to respond to "External changes from other processes or CloudKit sync" [3].
- **Apple's positioning.** Apple's iOS 26 release notes call SwiftData (iOS 17) and `NSPersistentCloudKitContainer` (iOS 13) the replacements for the deprecated iCloud Core Data ubiquity APIs [21]. At the WWDC26 SwiftData lab, engineers talked about moving away from `NSPredicate`-era APIs, and pointed to Core Data coexistence for any remaining gaps [4].
- **Scale guidance (WWDC26 lab) [4]:**
  - Many rows: "index them correctly" and "put limits on your fetch requests".
  - Large blobs: use `.externalStorage` [22].
  - Big imports: batch the inserts, and use a short-lived `ModelContext` per batch.
  - `@Query`: set a fetch limit, express all filtering in the predicate, and make sure an index covers it.

## Limitations vs alternatives

| Area | SwiftData | Core Data | GRDB |
|---|---|---|---|
| Min OS | iOS 17 [16] | Long-standing | iOS 13+, Swift 6.1+ [7] |
| Schema definition | `@Model` Swift classes (macros) | `.xcdatamodeld` or code | SQL tables + Swift record types [7] |
| Migrations | `VersionedSchema`, `SchemaMigrationPlan`, lightweight/custom `MigrationStage` [15][17] | Lightweight/heavyweight model migration [9] | `DatabaseMigrator` [7] |
| Aggregates (min/max/sum) | Not available; Apple suggests Core Data coexistence [4] | `NSExpression` | Raw SQL [7] |
| Observation outside SwiftUI | `ResultsObserver` from iOS 27 only [3] | `NSFetchedResultsController` | `ValueObservation` [7] |
| Unique constraints | `@Attribute(.unique)` / `#Unique` (upsert) [23][18] - but not with CloudKit [8] | Supported - but not with CloudKit [9] | SQL `UNIQUE` / upsert [7] |
| Indexes | `#Index` (iOS 18+) [19] | Fetch indexes | SQL indexes [7] |
| Custom/complex value types | Codable types; `.codable` escape hatch (iOS 27) is opaque to predicates and sorting, and does not trigger migrations when its shape changes [5] | Transformable | Codable records [7] |
| iCloud sync | Built in via `NSPersistentCloudKitContainer` [8] | `NSPersistentCloudKitContainer` [24] | None built in [7]; you would build it yourself on `CKSyncEngine` [25], or use a third-party layer such as Point-Free's SQLiteData (v1.12.0) [26] **[third-party, not evaluated]** |

- **Coexistence.** A Core Data stack and a SwiftData stack can share one store file. This needs:
  - class names that differ (entity names stay the same)
  - the same store URL for both stacks
  - persistent history tracking turned on in Core Data - without it the store opens read-only
  - both schemas kept in sync [27]

## CloudKit-later model constraints

How sync works, based on the documentation: SwiftData infers sync from the app's entitlements. `ModelConfiguration.CloudKitDatabase.automatic` (the default) turns on managed sync using the first container in the entitlements, and `.none` turns it off [8][28]. Sync needs the iCloud (CloudKit) capability and the Background Modes > Remote notifications capability [8].

Checklist for the v1 model:

- [ ] **Every stored attribute is optional or has a default value.** An Apple Frameworks Engineer shows both forms (`var timestamp: Date?` or `var timestamp: Date = Date()`) [10]. The CloudKit runtime error reads: "CloudKit integration requires that all attributes be optional, or have a default value set" [29].
- [ ] **Every relationship is optional** - in SwiftData, "nonoptional relationships" are not supported with CloudKit [8]. DTS explains why: sync does not deliver a whole object graph at once, so a relationship can show up as `nil` on another device. For callers, wrap the relationship in a computed property that returns `[]` instead of `nil` [11]. Example: `var exercise: Exercise?`, `var sets: [Set]? = []`. After a save, SwiftData stores an empty to-many relationship as `[]` rather than `nil` [12].
- [ ] **Every relationship has an inverse** ("in case the records synchronize out of order") [9]. Do not use `inverse: nil` unidirectional relationships [1] **[uncertain whether SwiftData rejects them at load time with CloudKit on; the Core Data rule says inverses are required]**.
- [ ] **No `.deny` delete rule.** CloudKit does not support the Deny deletion rule [9]. `.cascade`, `.nullify` (the default) and `.noAction` exist in SwiftData [30][31].
- [ ] **No `@Attribute(.unique)` or `#Unique`.** Unique constraints are unsupported with CloudKit [8][9]. Instead:
  - give each model a `var id: UUID = UUID()`-style field (default value, not unique-constrained)
  - dedupe in code, as Apple's sample does: sort duplicates by UUID, keep the lowest, and delete the rest later [13]
  - a creation timestamp is not a safe dedupe key, per DTS [14]
- [ ] **Plan for duplicate seed data.** Apple lists "Apps rely on some initial data and there's no way to allow only one peer to preload it" as a cause of duplicates [13]. The seeded Exercise Library starter list needs stable identifiers, or a dedupe pass once sync is on.
- [ ] **Do not rely on to-many order.** Core Data + CloudKit rejects ordered relationships ("CloudKit integration requires does not support ordered relationships") [32]. SwiftData's default store represents to-many relationships as a set [12]. Store an explicit order field (for example `var order: Int = 0` on Set) and sort by it.
- [ ] **No `Undefined` or objectID attribute types** [9].
- [ ] **Keep all synced models in one configuration.** Entities in one configuration must not have relationships to entities in another [9].
- [ ] **Treat names and types as permanent.** After production promotion, CloudKit schemas are additive only: record types and fields "are immutable and exist for all time". You can add new types and fields, but not modify or delete existing ones [8][9].
  - Renaming a Swift property with `@Attribute(originalName:)` keeps the local store intact [23]. Whether it keeps the CloudKit field name, or creates a new `CD_` field, is **[uncertain]** - CloudKit field names come from attribute names (`CD_[attribute.name]`) [33].
  - Apple lists three strategies for later production changes: add fields incrementally, add a `version` attribute to entities from the outset and filter by it, or migrate to a new store and container [9]. Adding a `version` attribute has to be decided in v1 to work "from the outset".
- [ ] **Keep large values out of synced records, or accept asset spill-over.** Records have a 1 MB limit. Core Data automatically moves large strings and data into `CKAsset` fields [33][34]. This is not a concern for reps/weight Sets.
- [ ] **Model concurrent edits as separate records, not merged flat values.** Conflict resolution is last-writer-wins per record [34]. Sets as their own records related to a Workout (not an array attribute on Workout) avoid collisions between devices [34].
- [ ] **Version the schema from v1.** Define `enum SchemaV1: VersionedSchema` and a `SchemaMigrationPlan` [15][17]. Apple engineers say you can version the current schema later and add earlier versions afterwards, but must test migration from every shipped version [4].
  - Making an attribute unique needs a custom (non-lightweight) stage with dedupe [15] - one more reason not to add unique constraints.
  - Whether custom migration stages are safe once CloudKit sync is on is **[uncertain]**. Apple's CloudKit guidance is framed around additive changes [9].
- [ ] **Do not purge persistent history.** SwiftData turns persistent history on automatically [27]. `NSPersistentCloudKitContainer` "relies on the history to figure out the changes on the store since last export". Purging it before export means local changes never sync [35]. Avoid calling `deleteHistory` [1] unless you know export has happened.
- [ ] **Keep the store at the default location or in an App Group.** A later Apple Watch app or widget needs an App Group container. With the default `ModelConfiguration`, SwiftData moves the store for you; with a custom URL, you must copy it yourself [4].
- [ ] **Know that sync cannot be toggled per data type in-app without two stores.** For opt-in sync, DTS suggests a local store plus a CloudKit store, and moving data across when the user opts in. DTS advises against an in-app sync toggle on a single store [35].
  - Whether existing local rows export automatically when sync is enabled on a store that predates it is **[uncertain]**. Community reports conflict, and no Apple statement was found [36].

## Sources

1. SwiftData updates - https://developer.apple.com/documentation/updates/swiftdata
2. SwiftData: Dive into inheritance and schema migration (WWDC25) - https://developer.apple.com/videos/play/wwdc2025/291/
3. ResultsObserver - https://developer.apple.com/documentation/swiftdata/resultsobserver ; HistoryObserver - https://developer.apple.com/documentation/swiftdata/historyobserver ; iOS & iPadOS 27 release notes - https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes
4. SwiftData Group Lab (WWDC26) - https://developer.apple.com/videos/play/wwdc2026/8017/
5. What's new in SwiftData (WWDC26) - https://developer.apple.com/videos/play/wwdc2026/274/
6. Forum: SwiftData relationship not updating after CloudKit sync (DTS reply) - https://developer.apple.com/forums/thread/763713
7. GRDB.swift README (v7.11.1, 2026-06-18) - https://github.com/groue/GRDB.swift
8. Syncing model data across a person's devices - https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices
9. Creating a Core Data model for CloudKit - https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit
10. Forum: SwiftData CloudKit integration requires optional/default (Frameworks Engineer reply) - https://developer.apple.com/forums/thread/739351
11. Forum: How to handle required relationships (DTS reply) - https://developer.apple.com/forums/thread/802713
12. Forum: SwiftData initializing optional array (DTS reply) - https://developer.apple.com/forums/thread/797666
13. Sharing Core Data objects between iCloud users - "Remove duplicate data" - https://developer.apple.com/documentation/coredata/sharing-core-data-objects-between-icloud-users
14. Forum: SwiftData and CloudKit deduplication (DTS reply) - https://developer.apple.com/forums/thread/772421
15. Model your schema with SwiftData (WWDC23) - https://developer.apple.com/videos/play/wwdc2023/10195/
16. Meet SwiftData (WWDC23) - https://developer.apple.com/videos/play/wwdc2023/10187/
17. VersionedSchema - https://developer.apple.com/documentation/swiftdata/versionedschema ; SchemaMigrationPlan - https://developer.apple.com/documentation/swiftdata/schemamigrationplan ; MigrationStage - https://developer.apple.com/documentation/swiftdata/migrationstage
18. Unique(_:) - https://developer.apple.com/documentation/swiftdata/unique(_:)
19. Index(_:) - https://developer.apple.com/documentation/swiftdata/index(_:)-74ia2
20. iOS & iPadOS 17 release notes - SwiftData - https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-17-release-notes
21. iOS & iPadOS 26 release notes - https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-26-release-notes
22. Schema.Attribute.Option.externalStorage - https://developer.apple.com/documentation/swiftdata/schema/attribute/option/externalstorage
23. Attribute(_:originalName:hashModifier:) - https://developer.apple.com/documentation/swiftdata/attribute(_:originalname:hashmodifier:)
24. Setting up Core Data with CloudKit - https://developer.apple.com/documentation/coredata/setting-up-core-data-with-cloudkit
25. CKSyncEngine - https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5
26. SQLiteData (third party) - https://github.com/pointfreeco/sqlite-data
27. Migrate to SwiftData (WWDC23) - https://developer.apple.com/videos/play/wwdc2023/10189/
28. ModelConfiguration.CloudKitDatabase - https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct ; .automatic - https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct/automatic
29. Forum: SwiftData CloudKit integration requires... (error text, Xcode 15 beta 7 fix) - https://developer.apple.com/forums/thread/735349
30. Schema.Relationship.DeleteRule - https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum
31. Relationship macro - https://developer.apple.com/documentation/swiftdata/relationship(_:deleterule:minimummodelcount:maximummodelcount:originalname:inverse:hashmodifier:)
32. Forum: CloudKit integration does not support ordered relationships (error text) - https://developer.apple.com/forums/thread/120041
33. Reading CloudKit records for Core Data - https://developer.apple.com/documentation/coredata/reading-cloudkit-records-for-core-data
34. Using Core Data with CloudKit (WWDC19) - https://developer.apple.com/videos/play/wwdc2019/202/
35. Forum: NSPersistentCloudKitContainer losing data (DTS reply) - https://developer.apple.com/forums/thread/764080
36. Forum: loading existing local data into NSPersistentCloudKitContainer (community replies only) - https://developer.apple.com/forums/thread/124626
