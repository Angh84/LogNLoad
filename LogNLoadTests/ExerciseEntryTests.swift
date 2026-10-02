import Foundation
import SwiftData
import Testing
@testable import LogNLoad

@MainActor
struct ExerciseEntryTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let entry: ExerciseEntry

    init() throws {
        container = try .logNLoad(inMemory: true)
        let workout = Workout(startedAt: .now)
        let bench = Exercise(name: "Barbell Bench Press", equipment: .barbell, muscleEmphases: [MuscleEmphasis(muscleGroup: .lowerChest, weight: 1)])
        container.mainContext.insert(workout)
        container.mainContext.insert(bench)
        entry = ExerciseEntry(workout: workout, exercise: bench, order: 0)
    }

    /// Adds Sets to the Entry in order; `true` makes a Warm-up Set.
    func sets(_ warmUps: Bool...) -> [WorkoutSet] {
        warmUps.enumerated().map { WorkoutSet(entry: entry, order: $0.offset, isWarmUp: $0.element) }
    }

    @Test func warmUpSetsAreLabelledWAndWorkingSetsNumberedInOrder() {
        let sets = sets(true, false, true, false, false)

        #expect(sets.map(entry.label) == ["W", "1", "W", "2", "3"])
    }

    @Test func aWorkingSetIsTitledByItsNumberAmongTheWorkingSets() {
        let sets = sets(true, false, false)

        #expect(sets.map(entry.title) == ["Warm-up", "Set 1 of 2", "Set 2 of 2"])
    }

    @Test func theFirstTargetSetSkipsCompletedSets() {
        let sets = sets(true, false, false)
        sets[0].completedAt = .now
        sets[2].completedAt = .now

        #expect(entry.firstTargetSet == sets[1])

        sets[1].completedAt = .now
        #expect(entry.firstTargetSet == nil)
    }

    @Test func theNoTargetHeadingCountsWorkingSets() {
        #expect(entry.noTargetHeading == "No Sets")

        _ = sets(true)
        #expect(entry.noTargetHeading == "All Sets done")

        _ = WorkoutSet(entry: entry, order: 1)
        #expect(entry.noTargetHeading == "All 1 Set done")

        _ = WorkoutSet(entry: entry, order: 2)
        #expect(entry.noTargetHeading == "All 2 Sets done")
    }
}
