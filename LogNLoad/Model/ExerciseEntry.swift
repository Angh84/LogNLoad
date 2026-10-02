import Foundation
import SwiftData

extension SchemaV1 {
    @Model final class ExerciseEntry {
        #Index<ExerciseEntry>([\.exercise])

        var id: UUID = UUID()
        var version: Int = 1
        var order: Int = 0
        var note: String?
        var workout: Workout?
        var exercise: Exercise?
        @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.entry)
        var sets: [WorkoutSet]? = []

        init(workout: Workout, exercise: Exercise, order: Int, note: String? = nil) {
            self.workout = workout
            self.exercise = exercise
            self.order = order
            self.note = trimmed(note)
        }
    }
}

extension ExerciseEntry {
    var sortedSets: [WorkoutSet] {
        (sets ?? []).sorted { $0.order < $1.order }
    }

    var firstTargetSet: WorkoutSet? {
        sortedSets.first(where: \.isTarget)
    }

    /// Whether Finish keeps this Entry.
    var hasCompletedSet: Bool {
        sortedSets.contains { !$0.isTarget }
    }

    /// "W" for a Warm-up Set; Working Sets are numbered from 1 in order.
    func label(of set: WorkoutSet) -> String {
        set.isWarmUp ? "W" : "\(workingSetNumber(of: set))"
    }

    /// "Warm-up", or "Set n of m" among the Working Sets.
    func title(of set: WorkoutSet) -> String {
        set.isWarmUp ? "Warm-up" : "Set \(workingSetNumber(of: set)) of \(sortedSets.count(where: \.isWorkingSet))"
    }

    /// The heading when no target Set is left.
    var noTargetHeading: String {
        let working = sortedSets.count(where: \.isWorkingSet)
        if working > 0 { return "All \(working) \(working == 1 ? "Set" : "Sets") done" }
        return sortedSets.isEmpty ? "No Sets" : "All Sets done"
    }

    private func workingSetNumber(of set: WorkoutSet) -> Int {
        sortedSets.prefix { $0 != set }.count(where: \.isWorkingSet) + 1
    }
}
