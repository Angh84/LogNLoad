import Foundation
import SwiftData

extension SchemaV1 {
    /// A Set. Named `WorkoutSet` because `Set` collides with Swift's `Set`.
    @Model final class WorkoutSet {
        var id: UUID = UUID()
        var version: Int = 1
        var order: Int = 0
        /// kg. Per implement for Dumbbell and Kettlebell, the total otherwise, read by the Exercise's Load Type.
        var weight: Double = 0
        var reps: Int = 0
        var repsLeft: Int = 0
        var repsRight: Int = 0
        /// 0 to 4, where 4 is "Easy". Never set on a Warm-up Set.
        var rir: Int?
        var isWarmUp: Bool = false
        var note: String?
        /// In the Active Workout, empty means a target Set.
        var completedAt: Date?
        var entry: ExerciseEntry?

        init(
            entry: ExerciseEntry,
            order: Int,
            weight: Double = 0,
            reps: Int = 0,
            repsLeft: Int = 0,
            repsRight: Int = 0,
            rir: Int? = nil,
            isWarmUp: Bool = false,
            note: String? = nil,
            completedAt: Date? = nil
        ) {
            self.entry = entry
            self.order = order
            self.weight = weight
            self.reps = reps
            self.repsLeft = repsLeft
            self.repsRight = repsRight
            self.rir = rir
            self.isWarmUp = isWarmUp
            self.note = trimmed(note)
            self.completedAt = completedAt
        }
    }
}

extension WorkoutSet {
    var isWorkingSet: Bool { !isWarmUp }

    /// Only in the Active Workout: in a finished Workout every Set is completed, and an empty `completedAt` means
    /// time unknown.
    var isTarget: Bool { completedAt == nil && entry?.workout?.isActive != false }

    /// A Warm-up Set never has an RIR, so marking one clears it; marking it a Working Set again leaves it empty.
    func setWarmUp(_ isWarmUp: Bool) {
        self.isWarmUp = isWarmUp
        if isWarmUp { rir = nil }
    }
}
