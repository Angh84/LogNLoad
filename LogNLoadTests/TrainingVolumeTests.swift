import Foundation
import SwiftData
import Testing
@testable import LogNLoad

@MainActor
struct TrainingVolumeTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    /// Today in these tests: 30 Sep 2026, so the window runs from 24 Sep.
    let today: Date

    init() throws {
        container = try .logNLoad(inMemory: true)
        today = DateComponents(calendar: .current, year: 2026, month: 9, day: 30, hour: 12).date!
    }

    func day(_ day: Int, _ hour: Int = 17, _ minute: Int = 0) -> Date {
        DateComponents(calendar: .current, year: 2026, month: 9, day: day, hour: hour, minute: minute).date!
    }

    func exercise(_ name: String, _ emphases: (MuscleGroup, Double)...) -> Exercise {
        let exercise = Exercise(name: name, equipment: .barbell, muscleEmphases: emphases.map { MuscleEmphasis(muscleGroup: $0.0, weight: $0.1) })
        context.insert(exercise)
        return exercise
    }

    /// A finished Workout started at `start`, ending an hour later.
    func finishedWorkout(at start: Date) -> Workout {
        let workout = Workout(startedAt: start, endedAt: start.addingTimeInterval(3600))
        context.insert(workout)
        return workout
    }

    /// Adds an Entry of `exercise` holding `warmUps` Warm-up Sets and `working` Working Sets completed at `completedAt`
    /// (the Workout's start by default), then `untimed` Working Sets without a completion time: target Sets in the
    /// Active Workout, Sets of unknown time in a finished one.
    func log(_ exercise: Exercise, in workout: Workout, warmUps: Int = 0, working: Int = 0, untimed: Int = 0, completedAt: Date? = nil) {
        let entry = ExerciseEntry(workout: workout, exercise: exercise, order: workout.entries?.count ?? 0)
        let time = completedAt ?? workout.startedAt
        let sets = Array(repeating: (isWarmUp: true, completedAt: time), count: warmUps)
            + Array(repeating: (isWarmUp: false, completedAt: time), count: working)
            + Array(repeating: (isWarmUp: false, completedAt: Date?.none), count: untimed)
        for (order, set) in sets.enumerated() {
            _ = WorkoutSet(entry: entry, order: order, weight: 60, reps: 10, isWarmUp: set.isWarmUp, completedAt: set.completedAt)
        }
    }

    /// Through the same window, query and sum as the Muscles tab.
    func volume() throws -> TrainingVolume {
        try context.save()
        let window = TrainingVolume.window(endingOn: today, calendar: .current)
        return TrainingVolume(try context.fetch(FetchDescriptor(predicate: Workout.predicate(startedIn: window))))
    }

    @Test func eachWorkingSetCountsItsExercisesMuscleEmphases() throws {
        let bench = exercise("Barbell Bench Press", (.upperChest, 1), (.triceps, 0.5))
        log(bench, in: finishedWorkout(at: day(29)), working: 3)

        let volume = try volume()

        #expect(volume[.upperChest] == 3)
        #expect(volume[.triceps] == 1.5)
        #expect(volume[.quads] == 0)
    }

    @Test func warmUpSetsDontCount() throws {
        let squat = exercise("Barbell Back Squat", (.quads, 1))
        log(squat, in: finishedWorkout(at: day(29)), warmUps: 2, working: 3)

        #expect(try volume()[.quads] == 3)
    }

    @Test func theActiveWorkoutCountsItsCompletedSetsButNotItsTargetSets() throws {
        let active = Workout(startedAt: day(30, 11))
        context.insert(active)
        log(exercise("Barbell Back Squat", (.quads, 1)), in: active, working: 2, untimed: 3)

        #expect(try volume()[.quads] == 2)
    }

    @Test func theWindowIsTodayAndTheSixDaysBefore() throws {
        let squat = exercise("Barbell Back Squat", (.quads, 1))
        log(squat, in: finishedWorkout(at: day(24, 0, 0)), working: 1)
        log(squat, in: finishedWorkout(at: day(23, 23, 59)), working: 10)

        #expect(try volume()[.quads] == 1)
    }

    @Test func aWorkoutCountsOnTheDayItStarted() throws {
        let squat = exercise("Barbell Back Squat", (.quads, 1))
        // Its Sets are completed after midnight, on the window's first day, but the Workout belongs to 23 Sep.
        log(squat, in: finishedWorkout(at: day(23, 23, 30)), working: 4, completedAt: day(24, 0, 10))

        #expect(try volume()[.quads] == 0)
    }

    @Test func emphasesAddUpAcrossExercisesAndWorkouts() throws {
        let bench = exercise("Barbell Bench Press", (.upperChest, 1), (.triceps, 0.5))
        let pushdown = exercise("Cable Triceps Pushdown", (.triceps, 1))
        let monday = finishedWorkout(at: day(28))
        log(bench, in: monday, working: 3)
        log(pushdown, in: monday, working: 2)
        log(bench, in: finishedWorkout(at: day(30, 8)), working: 1)

        let volume = try volume()

        #expect(volume[.upperChest] == 4)
        #expect(volume[.triceps] == 4)
    }

    @Test func aFinishedWorkoutsSetsCountWithoutACompletionTime() throws {
        let squat = exercise("Barbell Back Squat", (.quads, 1))
        let workout = finishedWorkout(at: day(29))
        log(squat, in: workout, untimed: 2)

        #expect(try volume()[.quads] == 2)
    }

    @Test func anArchivedExerciseStillCounts() throws {
        let squat = exercise("Barbell Back Squat", (.quads, 1))
        log(squat, in: finishedWorkout(at: day(29)), working: 3)
        squat.archive()

        #expect(squat.isArchived)
        #expect(try volume()[.quads] == 3)
    }

    @Test func editingAnExercisesEmphasesRecountsPastWorkouts() throws {
        let bench = exercise("Barbell Bench Press", (.upperChest, 1), (.triceps, 0.5))
        log(bench, in: finishedWorkout(at: day(26)), working: 4)
        try context.save()

        bench.update(
            name: "Barbell Bench Press", equipment: .barbell, loadType: .loaded, isUnilateral: false, note: "",
            muscleEmphases: [MuscleEmphasis(muscleGroup: .upperChest, weight: 1), MuscleEmphasis(muscleGroup: .triceps, weight: 0.25)]
        )

        #expect(try volume()[.triceps] == 1)
    }

    @Test func anEmptyWeekIsAllZeros() throws {
        let squat = exercise("Barbell Back Squat", (.quads, 1))
        log(squat, in: finishedWorkout(at: day(10)), working: 5)

        let volume = try volume()

        #expect(MuscleGroup.allCases.allSatisfy { volume[$0] == 0 })
    }

    @Test(arguments: [
        (0.0, VolumeBand.zero), (0.3, .under5), (4.9, .under5), (5, .from5), (9.9, .from5),
        (10, .from10), (19.9, .from10), (20, .from20), (31.5, .from20),
    ])
    func theBandEdges(volume: Double, band: VolumeBand) {
        #expect(VolumeBand(volume) == band)
    }

    @Test func volumeIsRoundedToOneDecimalBeforeItIsBanded() throws {
        // 12 Sets at a seed weight of 0.83 are 9.96 Sets.
        log(exercise("Leg Press", (.quads, 0.83)), in: finishedWorkout(at: day(29)), working: 12)

        let volume = try volume()

        #expect(volume[.quads] == 10)
        #expect(DisplayFormat.trainingVolume(volume[.quads], locale: Locale(identifier: "en_GB")) == "10.0")
        #expect(VolumeBand(volume[.quads]) == .from10)
    }
}
