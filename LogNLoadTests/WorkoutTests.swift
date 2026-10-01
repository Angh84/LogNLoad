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
