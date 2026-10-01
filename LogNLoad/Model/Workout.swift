import Foundation
import SwiftData

extension SchemaV1 {
    @Model final class Workout {
        #Index<Workout>([\.startedAt])

        /// Also the Health sync identifier, so it never changes (ADR-0002).
        var id: UUID = UUID()
        var version: Int = 1
        var startedAt: Date?
        /// Empty while this is the Active Workout.
        var endedAt: Date?
        var name: String?
        var note: String?
        var healthWriteCounter: Int = 1
        var healthConfirmedVersion: Int?
        @Relationship(deleteRule: .cascade, inverse: \ExerciseEntry.workout)
        var entries: [ExerciseEntry]? = []

        init(startedAt: Date, endedAt: Date? = nil, name: String? = nil, note: String? = nil) {
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.name = trimmed(name)
            self.note = trimmed(note)
        }
    }
}

extension Workout {
    var isActive: Bool { endedAt == nil }

    static func active(in context: ModelContext) throws -> Workout? {
        var descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.endedAt == nil })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    var sortedEntries: [ExerciseEntry] {
        (entries ?? []).sorted { $0.order < $1.order }
    }

    var isHealthPending: Bool {
        !isActive && healthConfirmedVersion != healthWriteCounter
    }
}
