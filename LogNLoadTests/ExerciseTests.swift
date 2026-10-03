import Foundation
import SwiftData
import Testing
@testable import LogNLoad

@MainActor
struct ExerciseTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try .logNLoad(inMemory: true)
    }

    func day(_ day: Int, _ hour: Int = 17) -> Date {
        DateComponents(calendar: .current, year: 2026, month: 9, day: day, hour: hour).date!
    }

    func exercise(
        _ name: String,
        _ equipment: Equipment = .barbell,
        loadType: LoadType = .loaded,
        isUnilateral: Bool = false,
        isArchived: Bool = false,
        emphases: [MuscleEmphasis] = [MuscleEmphasis(muscleGroup: .quads, weight: 1)]
    ) -> Exercise {
        let exercise = Exercise(name: name, equipment: equipment, loadType: loadType, isUnilateral: isUnilateral, isArchived: isArchived, muscleEmphases: emphases)
        context.insert(exercise)
        return exercise
    }

    func workout(_ startedAt: Date, endedAt: Date?) -> Workout {
        let workout = Workout(startedAt: startedAt, endedAt: endedAt)
        context.insert(workout)
        return workout
    }

    /// Adds an Entry for `exercise` to `workout` with one completed Set per (weight, reps).
    @discardableResult
    func log(_ exercise: Exercise, in workout: Workout, _ sets: [(weight: Double, reps: Int)]) -> [WorkoutSet] {
        let entry = ExerciseEntry(workout: workout, exercise: exercise, order: workout.entries?.count ?? 0)
        return sets.enumerated().map { index, set in
            WorkoutSet(entry: entry, order: index, weight: set.weight, reps: set.reps, completedAt: workout.startedAt)
        }
    }

    // MARK: Defaults and storage

    @Test func aNewExerciseHasTheSpecifiedDefaults() throws {
        let exercise = Exercise(name: "Squat", equipment: .barbell, muscleEmphases: [MuscleEmphasis(muscleGroup: .quads, weight: 1)])
        context.insert(exercise)
        try context.save()

        #expect(exercise.version == 1)
        #expect(exercise.loadType == .loaded)
        #expect(!exercise.isUnilateral)
        #expect(!exercise.isArchived)
        #expect(exercise.note == nil)
        #expect(exercise.entries == [])
    }

    @Test func aNewSetHasTheSpecifiedDefaults() throws {
        let entry = ExerciseEntry(workout: workout(day(30), endedAt: nil), exercise: exercise("Squat"), order: 0)
        let set = WorkoutSet(entry: entry, order: 0)
        try context.save()

        #expect(set.version == 1)
        #expect(set.weight == 0)
        #expect(set.reps == 0)
        #expect(set.repsLeft == 0)
        #expect(set.repsRight == 0)
        #expect(set.rir == nil)
        #expect(!set.isWarmUp)
        #expect(set.completedAt == nil)
        #expect(entry.version == 1)
    }

    @Test func muscleEmphasesAreStoredInTheirOrder() throws {
        let deadlift = exercise("Deadlift", emphases: [
            MuscleEmphasis(muscleGroup: .glutes, weight: 0.75),
            MuscleEmphasis(muscleGroup: .hamstrings, weight: 0.75),
            MuscleEmphasis(muscleGroup: .lowerBack, weight: 0.75),
            MuscleEmphasis(muscleGroup: .quads, weight: 0.5),
        ])
        try context.save()

        let stored = try #require(try ModelContext(container).fetch(FetchDescriptor<Exercise>()).first)
        #expect(stored.id == deadlift.id)
        #expect(stored.muscleEmphases.map(\.muscleGroup) == [.glutes, .hamstrings, .lowerBack, .quads])
        #expect(stored.muscleEmphases.map(\.weight) == [0.75, 0.75, 0.75, 0.5])
    }

    // MARK: Working Set

    @Test func aSetThatIsNotAWarmUpIsAWorkingSet() throws {
        let entry = ExerciseEntry(workout: workout(day(30), endedAt: nil), exercise: exercise("Squat"), order: 0)
        #expect(WorkoutSet(entry: entry, order: 0).isWorkingSet)
        #expect(!WorkoutSet(entry: entry, order: 1, isWarmUp: true).isWorkingSet)
    }

    // MARK: Compatible Exercise

    @Test func anExerciseWithTheSameLoadTypeSidesAndWeightConventionIsCompatible() {
        let bench = exercise("Barbell Bench Press", .barbell)
        #expect(exercise("Chest Press (Hoist)", .machine).isCompatible(with: bench))
        #expect(exercise("Cable Fly", .cable).isCompatible(with: bench))
    }

    @Test func aDifferentWeightConventionIsNotCompatible() {
        let bench = exercise("Barbell Bench Press", .barbell)
        #expect(!exercise("DB Bench Press", .dumbbell).isCompatible(with: bench))
        #expect(!bench.isCompatible(with: exercise("DB Bench Press 2", .dumbbell)))
        #expect(exercise("Kettlebell Press", .kettlebell).isCompatible(with: exercise("DB Press", .dumbbell)))
    }

    @Test func aDifferentLoadTypeOrSidednessIsNotCompatible() {
        let pullUp = exercise("Pull-up", .bodyweight, loadType: .bodyweight)
        #expect(!exercise("Assisted Pull-up", .machine, loadType: .assisted).isCompatible(with: pullUp))
        #expect(!exercise("Lat Pulldown", .machine).isCompatible(with: pullUp))
        #expect(!exercise("Single-arm Pull-up", .bodyweight, loadType: .bodyweight, isUnilateral: true).isCompatible(with: pullUp))
        #expect(exercise("Chin-up", .bodyweight, loadType: .bodyweight).isCompatible(with: pullUp))
    }

    @Test func anArchivedExerciseOrTheSameExerciseIsNotCompatible() {
        let bench = exercise("Barbell Bench Press")
        #expect(!exercise("Old Chest Press", .machine, isArchived: true).isCompatible(with: bench))
        #expect(!bench.isCompatible(with: bench))
    }

    // MARK: History

    @Test func anExerciseWithoutEntriesHasNoHistory() {
        let squat = exercise("Squat")
        #expect(!squat.hasHistory)
        #expect(squat.workoutCount == 0)
    }

    @Test func anEntryInTheActiveWorkoutCountsAsHistory() {
        let squat = exercise("Squat")
        log(squat, in: workout(day(30), endedAt: nil), [])
        #expect(squat.hasHistory)
        #expect(squat.workoutCount == 1)
    }

    @Test func historyCountsEveryWorkoutThatContainsTheExercise() {
        let squat = exercise("Squat")
        log(squat, in: workout(day(26), endedAt: day(26, 18)), [(100, 5)])
        log(squat, in: workout(day(28), endedAt: day(28, 18)), [(100, 5)])
        log(squat, in: workout(day(30), endedAt: nil), [])
        log(exercise("Bench"), in: workout(day(29), endedAt: day(29, 18)), [(60, 10)])
        #expect(squat.workoutCount == 3)
    }

    // MARK: Last Performance

    @Test func anExerciseNeverInAFinishedWorkoutHasNoLastPerformance() {
        let squat = exercise("Squat")
        #expect(squat.lastPerformance == nil)

        log(squat, in: workout(day(30), endedAt: nil), [(100, 5)])
        #expect(squat.lastPerformance == nil)
    }

    @Test func lastPerformanceComesFromTheFinishedWorkoutWithTheLatestStart() {
        let squat = exercise("Squat")
        let latest = log(squat, in: workout(day(28), endedAt: day(28, 18)), [(105, 5), (105, 4)])
        log(squat, in: workout(day(21), endedAt: day(21, 18)), [(100, 5)])
        log(squat, in: workout(day(24), endedAt: day(24, 18)), [(102.5, 5)])

        #expect(squat.lastPerformance == latest)
    }

    @Test func theActiveWorkoutNeverCountsAsLastPerformance() {
        let squat = exercise("Squat")
        let finished = log(squat, in: workout(day(28), endedAt: day(28, 18)), [(105, 5)])
        log(squat, in: workout(day(30), endedAt: nil), [(110, 5)])

        #expect(squat.lastPerformance == finished)
    }

    @Test func lastPerformanceHoldsEverySetInOrderIncludingWarmUps() throws {
        let squat = exercise("Squat")
        let finished = workout(day(28), endedAt: day(28, 18))
        let entry = ExerciseEntry(workout: finished, exercise: squat, order: 0)
        let working = WorkoutSet(entry: entry, order: 2, weight: 100, reps: 5, completedAt: day(28))
        let firstWarmUp = WorkoutSet(entry: entry, order: 0, weight: 40, reps: 10, isWarmUp: true, completedAt: day(28))
        let secondWarmUp = WorkoutSet(entry: entry, order: 1, weight: 70, reps: 5, isWarmUp: true, completedAt: day(28))
        try context.save()

        #expect(squat.lastPerformance == [firstWarmUp, secondWarmUp, working])
    }

    @Test func lastPerformanceFollowsAnEditedStartTime() {
        let squat = exercise("Squat")
        let earlier = workout(day(21), endedAt: day(21, 18))
        let earlierSets = log(squat, in: earlier, [(100, 5)])
        log(squat, in: workout(day(24), endedAt: day(24, 18)), [(102.5, 5)])

        earlier.startedAt = day(26)
        earlier.endedAt = day(26, 18)

        #expect(squat.lastPerformance == earlierSets)
    }

    // MARK: Muscle Emphasis display, Top Muscle Group and Body Area placement

    func deadlift() -> Exercise {
        exercise("Deadlift", emphases: [
            MuscleEmphasis(muscleGroup: .glutes, weight: 0.75),
            MuscleEmphasis(muscleGroup: .hamstrings, weight: 0.75),
            MuscleEmphasis(muscleGroup: .lowerBack, weight: 0.75),
            MuscleEmphasis(muscleGroup: .quads, weight: 0.5),
            MuscleEmphasis(muscleGroup: .traps, weight: 0.5),
            MuscleEmphasis(muscleGroup: .adductors, weight: 0.25),
        ])
    }

    @Test func emphasesDisplayHighestWeightFirstWithTiesInStoredOrder() {
        let chestPress = exercise("Chest Press (Hoist)", .machine, emphases: [
            MuscleEmphasis(muscleGroup: .lowerChest, weight: 0.5),
            MuscleEmphasis(muscleGroup: .triceps, weight: 0.5),
            MuscleEmphasis(muscleGroup: .frontDelts, weight: 0.75),
            MuscleEmphasis(muscleGroup: .upperChest, weight: 1),
        ])
        #expect(chestPress.emphasesInDisplayOrder.map(\.muscleGroup) == [.upperChest, .frontDelts, .lowerChest, .triceps])
        #expect(deadlift().emphasesInDisplayOrder.map(\.muscleGroup) == [.glutes, .hamstrings, .lowerBack, .quads, .traps, .adductors])
    }

    @Test func theTopMuscleGroupIsTheHighestWeightAndTheFirstInStoredOrderOnATie() {
        #expect(deadlift().topMuscleGroup == .glutes)
        #expect(exercise("Lat Pulldown", .cable, emphases: [
            MuscleEmphasis(muscleGroup: .biceps, weight: 0.5),
            MuscleEmphasis(muscleGroup: .lats, weight: 1),
        ]).topMuscleGroup == .lats)
    }

    @Test func anExerciseIsPlacedInTheBodyAreaOfItsTopMuscleGroup() {
        #expect(deadlift().bodyArea == .legs)
        #expect(exercise("Face Pull", .cable, emphases: [
            MuscleEmphasis(muscleGroup: .rearDelts, weight: 1),
            MuscleEmphasis(muscleGroup: .rotatorCuff, weight: 0.5),
            MuscleEmphasis(muscleGroup: .upperBack, weight: 1),
        ]).bodyArea == .shoulders)
    }

    // MARK: Name uniqueness

    @Test func aNameMatchesAnExistingExerciseIgnoringCaseAndSurroundingSpace() throws {
        let bench = exercise("Barbell Bench Press")
        try context.save()

        #expect(Exercise.named("barbell BENCH press", in: context) == bench)
        #expect(Exercise.named("  Barbell Bench Press \n", in: context) == bench)
        #expect(Exercise.named("Barbell Bench", in: context) == nil)
        #expect(Exercise.named("   ", in: context) == nil)
    }

    @Test func anArchivedExerciseKeepsItsNameReserved() throws {
        let archived = exercise("Pec Deck", isArchived: true)
        try context.save()

        #expect(Exercise.named("pec deck", in: context) == archived)
    }

    // MARK: Recent

    @Test func recentListsExercisesByTheirLatestFinishedWorkoutThenItsEntryOrder() throws {
        let squat = exercise("Squat"), bench = exercise("Bench"), row = exercise("Row"), curl = exercise("Curl")
        let older = workout(day(26), endedAt: day(26, 18))
        log(squat, in: older, [(60, 10)])
        log(curl, in: older, [(10, 10)])
        let newer = workout(day(28), endedAt: day(28, 18))
        log(row, in: newer, [(50, 10)])
        log(squat, in: newer, [(60, 10)])
        let active = workout(day(30), endedAt: nil)
        log(bench, in: active, [(40, 10)])
        try context.save()

        #expect(Exercise.recent(for: active, in: context) == [row, squat, curl])
    }

    @Test func recentLeavesOutTheWorkoutsOwnAndArchivedExercisesBeforeCountingToEight() throws {
        let names = (1...10).map { "Exercise \($0)" }
        let exercises = names.map { exercise($0) }
        let finished = workout(day(28), endedAt: day(28, 18))
        for exercise in exercises { log(exercise, in: finished, [(20, 10)]) }
        exercises[0].isArchived = true
        let active = workout(day(30), endedAt: nil)
        log(exercises[1], in: active, [(20, 10)])
        try context.save()

        #expect(Exercise.recent(for: active, in: context) == Array(exercises[2...9]))
    }

    @Test func recentIsEmptyWithoutFinishedWorkouts() throws {
        let active = workout(day(30), endedAt: nil)
        log(exercise("Squat"), in: active, [(60, 10)])
        try context.save()

        #expect(Exercise.recent(for: active, in: context).isEmpty)
    }

    @Test func recentLeavesOutWhatTheSwapPickerCannotOfferBeforeCountingToEight() throws {
        let exercises = (1...10).map { exercise("Exercise \($0)", $0.isMultiple(of: 2) ? .dumbbell : .barbell) }
        let finished = workout(day(28), endedAt: day(28, 18))
        for exercise in exercises { log(exercise, in: finished, [(20, 10)]) }
        let active = workout(day(30), endedAt: nil)
        try context.save()

        let recent = Exercise.recent(for: active, in: context) { $0.equipment == .barbell }

        #expect(recent.map(\.name) == ["Exercise 1", "Exercise 3", "Exercise 5", "Exercise 7", "Exercise 9"])
    }

    // MARK: Library

    @Test func withoutHistoryAnyEquipmentIsAllowed() {
        #expect(exercise("Row", .cable).allowedEquipment == Equipment.allCases)
    }

    @Test func historyKeepsEquipmentWithinItsWeightConvention() {
        let curl = exercise("Curl", .dumbbell)
        let row = exercise("Row", .cable)
        let workout = workout(day(28), endedAt: day(28, 18))
        log(curl, in: workout, [(14, 10)])
        log(row, in: workout, [(50, 10)])

        #expect(curl.allowedEquipment == [.dumbbell, .kettlebell])
        #expect(row.allowedEquipment == [.barbell, .machine, .cable, .band, .bodyweight, .other])
    }

    @Test func theLibraryListsExercisesByBodyAreaPlacementAToZWithoutArchivedOnes() {
        let squat = exercise("Squat", emphases: [MuscleEmphasis(muscleGroup: .quads, weight: 1)])
        let deadlift = exercise("Deadlift", emphases: [MuscleEmphasis(muscleGroup: .glutes, weight: 1), MuscleEmphasis(muscleGroup: .lowerBack, weight: 1)])
        let bench = exercise("Bench Press", emphases: [MuscleEmphasis(muscleGroup: .lowerChest, weight: 1), MuscleEmphasis(muscleGroup: .triceps, weight: 0.5)])
        let fly = exercise("Cable Fly", emphases: [MuscleEmphasis(muscleGroup: .upperChest, weight: 1)])
        let archived = exercise("Old Press", isArchived: true, emphases: [MuscleEmphasis(muscleGroup: .lowerChest, weight: 1)])

        let sections = Exercise.librarySections([squat, deadlift, archived, bench, fly])

        #expect(sections.map(\.area) == [.chest, .legs])
        #expect(sections.map(\.exercises) == [[bench, fly], [deadlift, squat]])
    }

    @Test func finishedHistoryIsNewestFirstWithoutTheActiveWorkout() {
        let squat = exercise("Squat")
        let older = workout(day(20), endedAt: day(20, 18))
        let newer = workout(day(27), endedAt: day(27, 18))
        let active = workout(day(30), endedAt: nil)
        log(squat, in: older, [(60, 10)])
        log(squat, in: newer, [(62.5, 10)])
        log(squat, in: active, [(65, 10)])

        #expect(squat.finishedHistory.map(\.workout) == [newer, older])
    }

    @Test func savingAnEditOfAnExerciseWithHistoryKeepsItsLockedFields() {
        let curl = exercise("Curl", .dumbbell)
        log(curl, in: workout(day(28), endedAt: day(28, 18)), [(14, 10)])

        curl.update(name: "Hammer Curl", equipment: .barbell, loadType: .assisted, isUnilateral: true, note: " Neutral grip ", muscleEmphases: [MuscleEmphasis(muscleGroup: .brachialis, weight: 1)])
        #expect(curl.name == "Hammer Curl")
        #expect(curl.equipment == .dumbbell)
        #expect(curl.loadType == .loaded)
        #expect(!curl.isUnilateral)
        #expect(curl.note == "Neutral grip")
        #expect(curl.muscleEmphases.map(\.muscleGroup) == [.brachialis])

        curl.update(name: "Hammer Curl", equipment: .kettlebell, loadType: .loaded, isUnilateral: false, note: "", muscleEmphases: curl.muscleEmphases)
        #expect(curl.equipment == .kettlebell)
    }

    @Test func savingAnEditOfAnExerciseWithoutHistoryChangesEveryField() {
        let row = exercise("Row", .cable)

        row.update(name: "Row", equipment: .dumbbell, loadType: .assisted, isUnilateral: true, note: "", muscleEmphases: row.muscleEmphases)

        #expect(row.equipment == .dumbbell)
        #expect(row.loadType == .assisted)
        #expect(row.isUnilateral)
    }

    // MARK: Archive and delete

    @Test func anExerciseWithHistoryIsArchived() {
        let squat = exercise("Squat")
        log(squat, in: workout(day(28), endedAt: day(28, 18)), [(60, 10)])

        #expect(squat.canArchive)
        squat.archive()

        #expect(squat.isArchived)
    }

    @Test func anExerciseWithoutHistoryIsNeverArchived() {
        let squat = exercise("Squat")

        #expect(!squat.canArchive)
        squat.archive()

        #expect(!squat.isArchived)
    }

    @Test func anExerciseInTheActiveWorkoutIsNeverArchived() {
        let squat = exercise("Squat")
        log(squat, in: workout(day(28), endedAt: day(28, 18)), [(60, 10)])
        log(squat, in: workout(day(30), endedAt: nil), [(62.5, 10)])

        #expect(squat.isInActiveWorkout)
        #expect(!squat.canArchive)
        squat.archive()

        #expect(!squat.isArchived)
    }

    @Test func anExerciseWithoutHistoryIsHardDeleted() throws {
        let squat = exercise("Squat")
        try context.save()

        squat.delete()
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 0)
    }

    @Test func anExerciseWithHistoryIsNeverDeleted() throws {
        let squat = exercise("Squat")
        log(squat, in: workout(day(28), endedAt: day(28, 18)), [(60, 10)])
        try context.save()

        squat.delete()
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 1)
    }

    @Test func aSeedIsKnownByItsSeedRecord() throws {
        let seed = SeedEntry("00000000-0000-0000-0000-000000000001", "Squat", .barbell, [.quads: 1.0])
        try SeedEntry.apply([seed], in: context)
        let custom = exercise("Zercher Squat")

        #expect(try #require(Exercise.named("Squat", in: context)).isSeed)
        #expect(!custom.isSeed)
    }
}
