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

    /// Starts the Active Workout at the tap time. There is at most one at a time.
    static func start(at date: Date, in context: ModelContext) throws -> Workout {
        guard try active(in: context) == nil else { throw WorkoutError.activeWorkoutExists }
        let workout = Workout(startedAt: date)
        context.insert(workout)
        try context.save()
        return workout
    }

    var sortedEntries: [ExerciseEntry] {
        (entries ?? []).sorted { $0.order < $1.order }
    }

    var isHealthPending: Bool {
        !isActive && healthConfirmedVersion != healthWriteCounter
    }

    /// Appends an Entry for `exercise`, prefilled with target Sets copied from its Last Performance,
    /// else one 0 kg x 0 target Set. An Exercise already in the Workout returns its Entry instead.
    func add(_ exercise: Exercise) -> ExerciseEntry {
        if let existing = sortedEntries.first(where: { $0.exercise == exercise }) { return existing }
        let entry = ExerciseEntry(workout: self, exercise: exercise, order: (sortedEntries.last?.order ?? -1) + 1)
        let prefill = exercise.lastPerformance ?? []
        for (order, set) in prefill.enumerated() {
            _ = WorkoutSet(entry: entry, order: order, weight: set.weight, reps: set.reps, repsLeft: set.repsLeft, repsRight: set.repsRight, isWarmUp: set.isWarmUp)
        }
        if prefill.isEmpty { _ = WorkoutSet(entry: entry, order: 0) }
        return entry
    }
}

enum WorkoutError: Error {
    case activeWorkoutExists
}
