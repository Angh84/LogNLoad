import SwiftData

/// The v1 store. Entity and attribute names are permanent once a CloudKit schema exists
/// (ADR-0001): a later change is a new schema version and a migration stage.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Workout.self, ExerciseEntry.self, WorkoutSet.self, Exercise.self, SeedRecord.self, PendingHealthDelete.self]
    }
}

enum LogNLoadMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

extension ModelContainer {
    static func logNLoad(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: SchemaV1.self),
            migrationPlan: LogNLoadMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }
}

typealias Workout = SchemaV1.Workout
typealias ExerciseEntry = SchemaV1.ExerciseEntry
typealias WorkoutSet = SchemaV1.WorkoutSet
typealias Exercise = SchemaV1.Exercise
typealias SeedRecord = SchemaV1.SeedRecord
typealias PendingHealthDelete = SchemaV1.PendingHealthDelete
