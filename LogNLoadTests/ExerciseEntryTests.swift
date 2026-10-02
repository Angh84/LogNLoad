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

    // MARK: Add Set

    @Test func addSetCopiesTheLastWorkingSetAsATarget() throws {
        _ = WorkoutSet(entry: entry, order: 0, weight: 60, reps: 10, repsLeft: 9, repsRight: 8, rir: 2, note: "Paused", completedAt: .now)
        _ = WorkoutSet(entry: entry, order: 1, weight: 20, reps: 5, isWarmUp: true, completedAt: .now)

        let added = entry.addSet()

        #expect(entry.sortedSets.last == added)
        #expect([added.weight, Double(added.reps), Double(added.repsLeft), Double(added.repsRight)] == [60, 10, 9, 8])
        #expect(added.isTarget)
        #expect(!added.isWarmUp)
        #expect(added.rir == nil && added.note == nil)
    }

    @Test func addSetCopiesTheLastSetAsAWorkingSetWhenThereIsNoWorkingSet() {
        _ = WorkoutSet(entry: entry, order: 0, weight: 20, reps: 10, isWarmUp: true)
        _ = WorkoutSet(entry: entry, order: 1, weight: 40, reps: 5, isWarmUp: true)

        let added = entry.addSet()

        #expect([added.weight, Double(added.reps)] == [40, 5])
        #expect(!added.isWarmUp)
    }

    @Test func addSetOnAnEntryWithoutSetsIsZeroByZero() {
        let added = entry.addSet()

        #expect(entry.sortedSets == [added])
        #expect([added.weight, Double(added.reps)] == [0, 0])
        #expect(added.isTarget)
    }
}
