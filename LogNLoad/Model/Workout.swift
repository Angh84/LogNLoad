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

    /// Its Exercises in Entry order.
    var exercises: [Exercise] {
        sortedEntries.compactMap(\.exercise)
    }

    func contains(_ exercise: Exercise) -> Bool {
        exercises.contains { $0.id == exercise.id }
    }

    /// Swap: the Entry changes to `exercise`, keeping its Sets and note. When the Workout already has an Entry for
    /// `exercise`, the two combine into that one.
    func swap(_ entry: ExerciseEntry, to exercise: Exercise) -> ExerciseEntry {
        if let existing = sortedEntries.first(where: { $0 != entry && $0.exercise?.id == exercise.id }) {
            existing.absorb(entry)
            return existing
        }
        entry.exercise = exercise
        return entry
    }

    /// Two Workouts overlap when each starts before the other ends. The Active Workout ends `now`.
    func overlaps(_ other: Workout, now: Date) -> Bool {
        guard let start = startedAt, let otherStart = other.startedAt else { return false }
        return start < (other.endedAt ?? now) && otherStart < (endedAt ?? now)
    }

    /// Its name, else its first two Exercise names and "+N" for the rest.
    var title: String {
        if let name { return name }
        let names = sortedEntries.compactMap(\.exercise?.name)
        let title = names.prefix(2).joined(separator: ", ")
        return names.count > 2 ? "\(title) +\(names.count - 2)" : title
    }

    /// The Set count on the History screens, which leaves out Warm-up Sets.
    var workingSetCount: Int {
        sortedEntries.flatMap(\.sortedSets).count(where: \.isWorkingSet)
    }

    var warmUpSetCount: Int {
        sortedEntries.flatMap(\.sortedSets).count(where: \.isWarmUp)
    }

    var isHealthPending: Bool {
        !isActive && healthConfirmedVersion != healthWriteCounter
    }

    /// The finished Workouts Health hasn't confirmed at their current `healthWriteCounter`, oldest first.
    static func healthPending(in context: ModelContext) -> [Workout] {
        var descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.endedAt != nil })
        descriptor.sortBy = [SortDescriptor(\.startedAt)]
        return ((try? context.fetch(descriptor)) ?? []).filter(\.isHealthPending)
    }

    /// What its next Health write saves: the stored times and the current sync version.
    var healthWorkout: HealthWorkout? {
        guard let startedAt, let endedAt else { return nil }
        return HealthWorkout(id: id, start: startedAt, end: endedAt, version: healthWriteCounter)
    }

    /// Appends an Entry for `exercise`. The Active Workout prefills it with target Sets copied from its Last
    /// Performance; otherwise, and while editing a finished Workout, it gets one 0 kg x 0 Set. An Exercise already in
    /// the Workout returns its Entry instead.
    func add(_ exercise: Exercise) -> ExerciseEntry {
        if let existing = sortedEntries.first(where: { $0.exercise?.id == exercise.id }) { return existing }
        let entry = ExerciseEntry(workout: self, exercise: exercise, order: (sortedEntries.last?.order ?? -1) + 1)
        let prefill = isActive ? exercise.lastPerformance ?? [] : []
        for (order, set) in prefill.enumerated() {
            _ = WorkoutSet(entry: entry, order: order, weight: set.weight, reps: set.reps, repsLeft: set.repsLeft, repsRight: set.repsRight, isWarmUp: set.isWarmUp)
        }
        if prefill.isEmpty { _ = WorkoutSet(entry: entry, order: 0) }
        return entry
    }

    var completedSets: [WorkoutSet] {
        sortedEntries.flatMap(\.sortedSets).filter { !$0.isTarget }
    }

    var targetSets: [WorkoutSet] {
        sortedEntries.flatMap(\.sortedSets).filter(\.isTarget)
    }

    /// The latest `completedAt` of its Sets.
    var lastCompletedAt: Date? {
        completedSets.compactMap(\.completedAt).max()
    }

    /// The last Completed Set's time, when it is more than 15 minutes before the Finish tap: the user then picks
    /// it (the default) or the tap time. Otherwise the Workout ends at the tap.
    func endTimeChoice(at tap: Date) -> Date? {
        guard let lastCompletedAt, tap.timeIntervalSince(lastCompletedAt) > 15 * 60 else { return nil }
        return lastCompletedAt
    }

    /// Drops every target Set, then every Entry left without Sets, its note included, then sets `endedAt`.
    /// A Workout with zero Completed Sets can't be finished.
    func finish(at end: Date) throws {
        guard !completedSets.isEmpty else { throw WorkoutError.noCompletedSets }
        guard let context = modelContext else { return }
        for entry in sortedEntries {
            if entry.hasCompletedSet {
                entry.sortedSets.filter(\.isTarget).forEach(context.delete)
            } else {
                context.delete(entry)
            }
        }
        endedAt = end
        try context.save()
    }

    /// Delete Workout: hard-deletes a finished Workout, its Entries and its Sets. No trash, no undo. A Pending Health
    /// delete takes its place until the next Health pass deletes its Health workouts.
    func delete() throws {
        guard let context = modelContext else { return }
        context.insert(PendingHealthDelete(workoutId: id))
        context.delete(self)
        try context.save()
    }

    /// Hard-deletes the Workout, its Entries and its Sets. Nothing reaches history or Health.
    func discard() throws {
        guard let context = modelContext else { return }
        context.delete(self)
        try context.save()
    }
}

enum WorkoutError: Error {
    case activeWorkoutExists
    case noCompletedSets
}
