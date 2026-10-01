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
}
