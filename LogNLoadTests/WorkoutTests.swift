import Foundation
import SwiftData
import Testing
@testable import LogNLoad

@MainActor
struct WorkoutTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try .logNLoad(inMemory: true)
    }

    func day(_ day: Int, _ hour: Int = 17) -> Date {
        DateComponents(calendar: .current, year: 2026, month: 9, day: day, hour: hour).date!
    }

    func benchPress() -> Exercise {
        let exercise = Exercise(name: "Barbell Bench Press", equipment: .barbell, muscleEmphases: [MuscleEmphasis(muscleGroup: .lowerChest, weight: 1)])
        context.insert(exercise)
        return exercise
    }

    /// Adds an Entry with one Set per flag to `workout`; `true` makes a Completed Set at `day(30)`.
    @discardableResult
    func entry(_ name: String, in workout: Workout, note: String? = nil, _ completed: Bool...) -> ExerciseEntry {
        let exercise = Exercise(name: name, equipment: .barbell, muscleEmphases: [MuscleEmphasis(muscleGroup: .quads, weight: 1)])
        context.insert(exercise)
        let entry = ExerciseEntry(workout: workout, exercise: exercise, order: workout.entries?.count ?? 0, note: note)
        for (order, isCompleted) in completed.enumerated() {
            _ = WorkoutSet(entry: entry, order: order, weight: 60, reps: 10, completedAt: isCompleted ? day(30) : nil)
        }
        return entry
    }

    @Test func theActiveWorkoutIsTheOneWithoutAnEnd() throws {
        let finished = Workout(startedAt: day(28), endedAt: day(28, 18))
        let active = Workout(startedAt: day(30))
        context.insert(finished)
        context.insert(active)
        try context.save()

        #expect(!finished.isActive)
        #expect(active.isActive)
        #expect(try Workout.active(in: context) == active)
    }

    @Test func thereIsNoActiveWorkoutWhenEveryWorkoutIsFinished() throws {
        context.insert(Workout(startedAt: day(28), endedAt: day(28, 18)))
        try context.save()

        #expect(try Workout.active(in: context) == nil)
    }

    @Test func aNewWorkoutHasTheSpecifiedDefaults() throws {
        let workout = Workout(startedAt: day(30))
        context.insert(workout)
        try context.save()

        #expect(workout.version == 1)
        #expect(workout.healthWriteCounter == 1)
        #expect(workout.healthConfirmedVersion == nil)
        #expect(workout.endedAt == nil)
        #expect(workout.entries == [])
    }

    @Test func aFinishedWorkoutIsHealthPendingUntilHealthConfirmsItsCounter() {
        let workout = Workout(startedAt: day(28), endedAt: day(28, 18))
        #expect(workout.isHealthPending)

        workout.healthConfirmedVersion = 1
        #expect(!workout.isHealthPending)

        workout.healthWriteCounter = 2
        #expect(workout.isHealthPending)
    }

    @Test func theActiveWorkoutIsNeverHealthPending() {
        #expect(!Workout(startedAt: day(30)).isHealthPending)
    }

    @Test func entriesAndSetsReadInTheirStoredOrder() throws {
        let workout = Workout(startedAt: day(30))
        context.insert(workout)
        let squat = Exercise(name: "Squat", equipment: .barbell, muscleEmphases: [MuscleEmphasis(muscleGroup: .quads, weight: 1)])
        let row = Exercise(name: "Row", equipment: .cable, muscleEmphases: [MuscleEmphasis(muscleGroup: .upperBack, weight: 1)])
        let bench = benchPress()
        context.insert(squat)
        context.insert(row)
        let second = ExerciseEntry(workout: workout, exercise: squat, order: 1)
        let third = ExerciseEntry(workout: workout, exercise: row, order: 2)
        let first = ExerciseEntry(workout: workout, exercise: bench, order: 0)
        let setB = WorkoutSet(entry: first, order: 1)
        let setC = WorkoutSet(entry: first, order: 2)
        let setA = WorkoutSet(entry: first, order: 0)
        try context.save()

        #expect(workout.sortedEntries == [first, second, third])
        #expect(first.sortedSets == [setA, setB, setC])
    }

    @Test func deletingAWorkoutDeletesItsEntriesAndTheirSets() throws {
        let workout = Workout(startedAt: day(28), endedAt: day(28, 18))
        context.insert(workout)
        let bench = benchPress()
        let entry = ExerciseEntry(workout: workout, exercise: bench, order: 0)
        _ = WorkoutSet(entry: entry, order: 0, weight: 60, reps: 10, completedAt: day(28))
        _ = WorkoutSet(entry: entry, order: 1, weight: 60, reps: 9, completedAt: day(28))
        try context.save()

        context.delete(workout)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ExerciseEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutSet>()) == 0)
        #expect(try context.fetch(FetchDescriptor<Exercise>()) == [bench])
    }

    @Test func deletingAnEntryDeletesOnlyItsSets() throws {
        let workout = Workout(startedAt: day(30))
        context.insert(workout)
        let squat = Exercise(name: "Squat", equipment: .barbell, muscleEmphases: [MuscleEmphasis(muscleGroup: .quads, weight: 1)])
        context.insert(squat)
        let removed = ExerciseEntry(workout: workout, exercise: benchPress(), order: 0)
        _ = WorkoutSet(entry: removed, order: 0)
        let kept = ExerciseEntry(workout: workout, exercise: squat, order: 1)
        let keptSet = WorkoutSet(entry: kept, order: 0)
        try context.save()

        context.delete(removed)
        try context.save()

        #expect(workout.sortedEntries == [kept])
        #expect(try context.fetch(FetchDescriptor<WorkoutSet>()) == [keptSet])
    }

    // MARK: Start

    @Test func startCreatesTheActiveWorkoutAtTheTapTime() throws {
        let workout = try Workout.start(at: day(30), in: context)

        let fresh = ModelContext(container)
        let stored = try #require(try Workout.active(in: fresh))
        #expect(stored.id == workout.id)
        #expect(stored.startedAt == day(30))
        #expect(stored.entries == [])
    }

    @Test func noSecondWorkoutStartsWhileOneIsActive() throws {
        _ = try Workout.start(at: day(30), in: context)

        #expect(throws: WorkoutError.activeWorkoutExists) {
            try Workout.start(at: day(30, 18), in: context)
        }
        #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 1)
    }

    @Test func aWorkoutStartsOnceTheLastOneIsFinished() throws {
        context.insert(Workout(startedAt: day(28), endedAt: day(28, 18)))
        try context.save()

        let workout = try Workout.start(at: day(30), in: context)

        #expect(try Workout.active(in: context) == workout)
    }

    // MARK: Adding an Exercise

    @Test func anExerciseWithoutLastPerformanceGetsOneEmptyTargetSet() throws {
        let workout = try Workout.start(at: day(30), in: context)
        let bench = benchPress()

        let entry = workout.add(bench)

        #expect(workout.sortedEntries == [entry])
        #expect(entry.exercise == bench)
        let set = try #require(entry.sortedSets.first)
        #expect(entry.sortedSets.count == 1)
        #expect(set.weight == 0)
        #expect(set.reps == 0)
        #expect(set.completedAt == nil)
        #expect(!set.isWarmUp)
    }

    @Test func prefillCopiesLastPerformanceAsTargetSetsInOrder() throws {
        let bench = benchPress()
        let last = Workout(startedAt: day(28), endedAt: day(28, 18))
        context.insert(last)
        let lastEntry = ExerciseEntry(workout: last, exercise: bench, order: 0, note: "Wide grip")
        _ = WorkoutSet(entry: lastEntry, order: 0, weight: 20, reps: 10, isWarmUp: true, completedAt: day(28))
        _ = WorkoutSet(entry: lastEntry, order: 1, weight: 62.5, reps: 10, rir: 2, note: "Felt heavy", completedAt: day(28))
        _ = WorkoutSet(entry: lastEntry, order: 2, weight: 62.5, reps: 0, rir: 0, completedAt: day(28))
        let workout = try Workout.start(at: day(30), in: context)

        let entry = workout.add(bench)

        let values = entry.sortedSets.map { [$0.weight, Double($0.reps), $0.isWarmUp ? 1 : 0] }
        #expect(values == [[20, 10, 1], [62.5, 10, 0], [62.5, 0, 0]])
        #expect(entry.sortedSets.allSatisfy { $0.completedAt == nil && $0.rir == nil && $0.note == nil })
        #expect(entry.note == nil)
    }

    @Test func prefillCopiesBothSidesOfAUnilateralExercise() throws {
        let curl = Exercise(name: "Concentration Curl", equipment: .dumbbell, isUnilateral: true, muscleEmphases: [MuscleEmphasis(muscleGroup: .biceps, weight: 1)])
        context.insert(curl)
        let last = Workout(startedAt: day(28), endedAt: day(28, 18))
        context.insert(last)
        _ = WorkoutSet(entry: ExerciseEntry(workout: last, exercise: curl, order: 0), order: 0, weight: 14, repsLeft: 10, repsRight: 9, completedAt: day(28))
        let workout = try Workout.start(at: day(30), in: context)

        let set = try #require(workout.add(curl).sortedSets.first)

        #expect(set.weight == 14)
        #expect(set.repsLeft == 10)
        #expect(set.repsRight == 9)
    }

    @Test func prefillIsASnapshotOfLastPerformance() throws {
        let bench = benchPress()
        let last = Workout(startedAt: day(28), endedAt: day(28, 18))
        context.insert(last)
        let lastSet = WorkoutSet(entry: ExerciseEntry(workout: last, exercise: bench, order: 0), order: 0, weight: 60, reps: 10, completedAt: day(28))
        let workout = try Workout.start(at: day(30), in: context)
        let entry = workout.add(bench)

        lastSet.weight = 70
        context.delete(last)
        try context.save()

        #expect(entry.sortedSets.map(\.weight) == [60])
    }

    @Test func aNewEntryIsAppendedAfterTheLastOne() throws {
        let workout = try Workout.start(at: day(30), in: context)
        let squat = Exercise(name: "Squat", equipment: .barbell, muscleEmphases: [MuscleEmphasis(muscleGroup: .quads, weight: 1)])
        context.insert(squat)
        let first = workout.add(benchPress())

        let second = workout.add(squat)

        #expect(workout.sortedEntries == [first, second])
    }

    @Test func addingAnExerciseAlreadyInTheWorkoutReturnsItsEntry() throws {
        let workout = try Workout.start(at: day(30), in: context)
        let bench = benchPress()
        let entry = workout.add(bench)

        #expect(workout.add(bench) == entry)
        #expect(workout.sortedEntries == [entry])
        #expect(entry.sortedSets.count == 1)
    }

    // MARK: Finish

    @Test func finishingDropsTargetSetsThenEntriesLeftWithoutSetsThenSetsTheEnd() throws {
        let workout = try Workout.start(at: day(30), in: context)
        let squat = entry("Squat", in: workout, true, false, true)
        entry("Bench", in: workout, note: "Wide grip", false, false)
        let row = entry("Row", in: workout, true)

        try workout.finish(at: day(30, 18))

        let fresh = ModelContext(container)
        let stored = try #require(try fresh.fetch(FetchDescriptor<Workout>()).first)
        #expect(stored.endedAt == day(30, 18))
        #expect(stored.sortedEntries.map(\.id) == [squat.id, row.id])
        #expect(stored.sortedEntries.map { $0.sortedSets.count } == [2, 1])
        #expect(try fresh.fetch(FetchDescriptor<WorkoutSet>()).allSatisfy { $0.completedAt != nil })
        #expect(try fresh.fetch(FetchDescriptor<ExerciseEntry>()).allSatisfy { $0.note == nil })
    }

    @Test func aWorkoutWithZeroCompletedSetsCantBeFinished() throws {
        let workout = try Workout.start(at: day(30), in: context)
        entry("Squat", in: workout, false, false)

        #expect(throws: WorkoutError.noCompletedSets) {
            try workout.finish(at: day(30, 18))
        }
        #expect(workout.isActive)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutSet>()) == 2)
    }

    @Test func finishingWithinFifteenMinutesOfTheLastCompletedSetEndsAtTheTap() throws {
        let workout = try Workout.start(at: day(30), in: context)
        let squat = entry("Squat", in: workout, true, true)
        squat.sortedSets[1].completedAt = day(30, 18)

        #expect(workout.endTimeChoice(at: day(30, 18).addingTimeInterval(15 * 60)) == nil)
    }

    @Test func finishingLaterOffersTheLatestCompletedSetsTime() throws {
        let workout = try Workout.start(at: day(30), in: context)
        let squat = entry("Squat", in: workout, true, false)
        let bench = entry("Bench", in: workout, true)
        bench.sortedSets[0].completedAt = day(30, 18)
        squat.sortedSets[0].completedAt = day(30, 17).addingTimeInterval(600)

        #expect(workout.endTimeChoice(at: day(30, 18).addingTimeInterval(15 * 60 + 1)) == day(30, 18))
    }

    @Test func aWorkoutStartedAfterFinishingOnePrefillsFromIt() throws {
        let first = try Workout.start(at: day(29), in: context)
        let squat = entry("Squat", in: first, true, true, false)
        squat.sortedSets[1].weight = 70
        try first.finish(at: day(29, 18))
        let exercise = try #require(squat.exercise)

        let second = try Workout.start(at: day(30), in: context)
        let prefilled = second.add(exercise)

        #expect(prefilled.sortedSets.map(\.weight) == [60, 70])
        #expect(prefilled.sortedSets.allSatisfy { $0.isTarget })
    }

    // MARK: Discard

    @Test func discardingDeletesTheWorkoutItsEntriesAndSetsButKeepsTheExercises() throws {
        let workout = try Workout.start(at: day(30), in: context)
        entry("Squat", in: workout, true, false)
        entry("Bench", in: workout, false)

        try workout.discard()

        let fresh = ModelContext(container)
        #expect(try fresh.fetchCount(FetchDescriptor<Workout>()) == 0)
        #expect(try fresh.fetchCount(FetchDescriptor<ExerciseEntry>()) == 0)
        #expect(try fresh.fetchCount(FetchDescriptor<WorkoutSet>()) == 0)
        #expect(try fresh.fetchCount(FetchDescriptor<Exercise>()) == 2)
    }

    @Test func namesAndNotesAreStoredTrimmedAndEmptyAsNoValue() throws {
        let workout = Workout(startedAt: day(30), name: "  Push day \n", note: " \n ")
        context.insert(workout)
        let exercise = Exercise(name: " Chest Press (Hoist) ", equipment: .machine, note: "\n Seat 4,  pin 7 \n", muscleEmphases: [MuscleEmphasis(muscleGroup: .lowerChest, weight: 1)])
        context.insert(exercise)
        let entry = ExerciseEntry(workout: workout, exercise: exercise, order: 0, note: "   ")
        _ = WorkoutSet(entry: entry, order: 0, note: " felt heavy ")
        try context.save()

        let fresh = ModelContext(container)
        let storedWorkout = try #require(try fresh.fetch(FetchDescriptor<Workout>()).first)
        let storedExercise = try #require(try fresh.fetch(FetchDescriptor<Exercise>()).first)
        let storedEntry = try #require(try fresh.fetch(FetchDescriptor<ExerciseEntry>()).first)
        let storedSet = try #require(try fresh.fetch(FetchDescriptor<WorkoutSet>()).first)
        #expect(storedWorkout.name == "Push day")
        #expect(storedWorkout.note == nil)
        #expect(storedExercise.name == "Chest Press (Hoist)")
        #expect(storedExercise.note == "Seat 4,  pin 7")
        #expect(storedEntry.note == nil)
        #expect(storedSet.note == "felt heavy")
    }
}
