import SwiftData
import Testing
@testable import LogNLoad

struct SchemaTests {
    let schema = Schema(versionedSchema: SchemaV1.self)

    func entity(_ name: String) throws -> Schema.Entity {
        try #require(schema.entities.first { $0.name == name })
    }

    @Test func theEntityNamesAreTheSwiftTypeNames() {
        #expect(Set(schema.entities.map(\.name)) == ["Workout", "ExerciseEntry", "WorkoutSet", "Exercise", "SeedRecord", "PendingHealthDelete"])
    }

    @Test(arguments: [
        ("Workout", ["id", "version", "startedAt", "endedAt", "name", "note", "healthWriteCounter", "healthConfirmedVersion", "entries"]),
        ("ExerciseEntry", ["id", "version", "order", "note", "workout", "exercise", "sets"]),
        ("WorkoutSet", ["id", "version", "order", "weight", "reps", "repsLeft", "repsRight", "rir", "isWarmUp", "note", "completedAt", "entry"]),
        ("Exercise", ["id", "version", "name", "equipment", "loadType", "isUnilateral", "note", "isArchived", "muscleEmphases", "entries"]),
        ("SeedRecord", ["id", "version", "fingerprint"]),
        ("PendingHealthDelete", ["id", "version", "workoutId"]),
    ])
    func eachEntityStoresExactlyTheSpecifiedProperties(name: String, properties: [String]) throws {
        #expect(Set(try entity(name).storedPropertiesByName.keys) == Set(properties))
    }

    @Test func everyAttributeIsOptionalOrDefaulted() {
        for entity in schema.entities {
            for attribute in entity.attributes {
                #expect(attribute.isOptional || attribute.defaultValue != nil, "\(entity.name).\(attribute.name)")
            }
        }
    }

    @Test func everyRelationshipIsOptionalWithAnInverseAndNeverDenies() {
        for entity in schema.entities {
            for relationship in entity.relationships {
                let label = "\(entity.name).\(relationship.name)"
                #expect(relationship.isOptional, "\(label)")
                #expect(relationship.inverseKeyPath != nil || relationship.inverseName != nil, "\(label)")
                #expect(relationship.deleteRule != .deny, "\(label)")
            }
        }
    }

    @Test func nothingIsUnique() {
        for entity in schema.entities {
            #expect(entity.uniquenessConstraints.isEmpty, "\(entity.name)")
            for attribute in entity.attributes {
                #expect(!attribute.isUnique, "\(entity.name).\(attribute.name)")
            }
            for relationship in entity.relationships {
                #expect(!relationship.isUnique, "\(entity.name).\(relationship.name)")
            }
        }
    }

    @Test func theToManyDeleteRulesFollowTheSpec() throws {
        #expect(try entity("Workout").relationshipsByName["entries"]?.deleteRule == .cascade)
        #expect(try entity("ExerciseEntry").relationshipsByName["sets"]?.deleteRule == .cascade)
        #expect(try entity("Exercise").relationshipsByName["entries"]?.deleteRule == .nullify)
    }

    @Test func workoutStartAndEntryExerciseAreIndexed() throws {
        // Each index is reported as its kind followed by its properties.
        #expect(try entity("Workout").indices == [["binary", "startedAt"]])
        #expect(try entity("ExerciseEntry").indices == [["binary", "exercise"]])
    }
}
