import Foundation
import SwiftData
import Testing
@testable import LogNLoad

@MainActor
struct LoggingSessionTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let workout: Workout

    init() throws {
        container = try .logNLoad(inMemory: true)
        workout = try Workout.start(at: Self.started, in: container.mainContext)
    }

    static let started = DateComponents(calendar: .current, year: 2026, month: 9, day: 30, hour: 17).date!

    func exercise(_ name: String) -> Exercise {
        let exercise = Exercise(name: name, equipment: .barbell, muscleEmphases: [MuscleEmphasis(muscleGroup: .quads, weight: 1)])
        context.insert(exercise)
        return exercise
    }

    /// Adds an Entry with one Set per flag; `true` makes a Completed Set.
    @discardableResult
    func entry(_ name: String, _ completed: Bool...) -> ExerciseEntry {
        let entry = ExerciseEntry(workout: workout, exercise: exercise(name), order: workout.entries?.count ?? 0)
        for (order, isCompleted) in completed.enumerated() {
            _ = WorkoutSet(entry: entry, order: order, weight: 60, reps: 10, completedAt: isCompleted ? Self.started : nil)
        }
        return entry
    }

    // MARK: Opening

    @Test func opensOnTheFirstTargetSetOfTheFirstEntryWithOne() {
        entry("Squat", true, true)
        let bench = entry("Bench", true, false, false)
        entry("Row", false)

        let session = LoggingSession(workout: workout)

        #expect(session.currentEntry == bench)
        #expect(session.currentSet == bench.sortedSets[1])
    }

    @Test func opensOnTheLastEntryWithNoTargetWhenNoEntryHasOne() {
        entry("Squat", true)
        let bench = entry("Bench", true, true)

        let session = LoggingSession(workout: workout)

        #expect(session.currentEntry == bench)
        #expect(session.currentSet == nil)
        #expect(session.heading == "All 2 Sets done")
    }

    @Test func anEmptyWorkoutHasNoCurrentEntry() {
        let session = LoggingSession(workout: workout)

        #expect(session.currentEntry == nil)
        #expect(session.currentSet == nil)
        #expect(session.heading == nil)
    }

    // MARK: Adding an Exercise

    @Test func anAddedExerciseBecomesCurrentOnItsFirstTargetSetAndIsSaved() throws {
        entry("Squat", true)
        let session = LoggingSession(workout: workout)

        session.add(exercise("Bench"))

        let added = try #require(workout.sortedEntries.last)
        #expect(added.exercise?.name == "Bench")
        #expect(session.currentEntry == added)
        #expect(session.currentSet == added.sortedSets.first)
        let fresh = ModelContext(container)
        #expect(try fresh.fetchCount(FetchDescriptor<ExerciseEntry>()) == 2)
    }

    @Test func pickingAnExerciseAlreadyInTheWorkoutGoesToItsEntry() throws {
        let squat = entry("Squat", true, false)
        entry("Bench", false)
        let session = LoggingSession(workout: workout)
        session.select(workout.sortedEntries[1])

        session.add(try #require(squat.exercise))

        #expect(workout.sortedEntries.count == 2)
        #expect(session.currentEntry == squat)
        #expect(session.currentSet == squat.sortedSets[1])
    }

    // MARK: Set loop

    static let tap = started.addingTimeInterval(600)

    @Test func completingAWorkingSetSavesItsTimeAndAsksForRIR() throws {
        let bench = entry("Bench", false, false)
        let session = LoggingSession(workout: workout)
        let first = bench.sortedSets[0]

        session.complete(at: Self.tap)

        #expect(first.completedAt == Self.tap)
        #expect(first.weight == 60)
        #expect(first.reps == 10)
        #expect(session.isAskingRIR)
        #expect(session.currentSet == first)
        let fresh = ModelContext(container)
        let stored = try fresh.fetch(FetchDescriptor<WorkoutSet>()).filter { $0.id == first.id }
        #expect(stored.first?.completedAt == Self.tap)
    }

    @Test func answeringRIRRecordsItAndMovesToTheNextTargetSet() {
        let bench = entry("Bench", false, false)
        let session = LoggingSession(workout: workout)
        session.complete(at: Self.tap)

        session.recordRIR(4)

        #expect(bench.sortedSets[0].rir == 4)
        #expect(!session.isAskingRIR)
        #expect(session.currentSet == bench.sortedSets[1])
    }

    @Test func skippingRIRLeavesItEmpty() {
        let bench = entry("Bench", false, false)
        let session = LoggingSession(workout: workout)
        session.complete(at: Self.tap)

        session.recordRIR(nil)

        #expect(bench.sortedSets[0].rir == nil)
        #expect(session.currentSet == bench.sortedSets[1])
    }

    @Test func completingAWarmUpSetMovesOnWithoutAskingForRIR() {
        let bench = entry("Bench", false, false)
        bench.sortedSets[0].isWarmUp = true
        let session = LoggingSession(workout: workout)

        session.complete(at: Self.tap)

        #expect(bench.sortedSets[0].completedAt == Self.tap)
        #expect(!session.isAskingRIR)
        #expect(session.currentSet == bench.sortedSets[1])
    }

    @Test func completingTheLastTargetSetShowsTheNoTargetState() {
        let bench = entry("Bench", true, false)
        let session = LoggingSession(workout: workout)

        session.complete(at: Self.tap)
        session.recordRIR(2)

        #expect(session.currentEntry == bench)
        #expect(session.currentSet == nil)
        #expect(session.heading == "All 2 Sets done")
    }

    @Test func undoingACompletionMakesTheSetATargetAgainWithItsValues() throws {
        let bench = entry("Bench", true, true)
        let session = LoggingSession(workout: workout)
        let second = bench.sortedSets[1]
        session.select(second)

        session.undoCompletion()

        #expect(second.completedAt == nil)
        #expect(second.weight == 60)
        #expect(second.reps == 10)
        #expect(session.currentSet == second)
        #expect(session.heading == "Set 2 of 2")
        let fresh = ModelContext(container)
        let stored = try fresh.fetch(FetchDescriptor<WorkoutSet>()).filter { $0.id == second.id }
        #expect(stored.first?.completedAt == nil)
    }

    @Test func tappingASetRowMakesItCurrentAndClosesTheRIRPanel() {
        let bench = entry("Bench", false, false)
        let session = LoggingSession(workout: workout)
        session.complete(at: Self.tap)

        session.select(bench.sortedSets[1])

        #expect(session.currentSet == bench.sortedSets[1])
        #expect(!session.isAskingRIR)
    }

    @Test func nextSetGoesToTheFirstTargetSetOrTheNoTargetState() {
        let bench = entry("Bench", false, true, false)
        let session = LoggingSession(workout: workout)
        session.select(bench.sortedSets[1])

        session.nextSet()
        #expect(session.currentSet == bench.sortedSets[0])

        bench.sortedSets[0].completedAt = Self.tap
        bench.sortedSets[2].completedAt = Self.tap
        session.select(bench.sortedSets[1])
        session.nextSet()
        #expect(session.currentSet == nil)
    }

    @Test func tappingAChipMakesItsEntryCurrentOnItsFirstTargetSet() {
        let squat = entry("Squat", false)
        let bench = entry("Bench", true, false)
        let session = LoggingSession(workout: workout)
        #expect(session.currentEntry == squat)

        session.select(bench)

        #expect(session.currentEntry == bench)
        #expect(session.currentSet == bench.sortedSets[1])
    }

    // MARK: Steppers

    @Test func weightIsStoredToTwoDecimalsAndNeverBelowZero() {
        let bench = entry("Bench", false)
        let session = LoggingSession(workout: workout)
        let set = bench.sortedSets[0]

        session.changeWeight(to: 61.256)
        #expect(set.weight == 61.26)

        session.changeWeight(to: -2.5)
        #expect(set.weight == 0)
    }

    @Test func aWeightThatIsNotANumberIsIgnored() {
        let bench = entry("Bench", false)
        let session = LoggingSession(workout: workout)
        let set = bench.sortedSets[0]

        session.changeWeight(to: .nan)
        session.changeWeight(to: .infinity)

        #expect(set.weight == 60)
    }

    @Test func repsAreNeverBelowZero() {
        let bench = entry("Bench", false)
        let session = LoggingSession(workout: workout)
        let set = bench.sortedSets[0]

        session.changeReps(\.reps, to: 12)
        session.changeReps(\.repsLeft, to: -1)
        session.changeReps(\.repsRight, to: 9)

        #expect(set.reps == 12)
        #expect(set.repsLeft == 0)
        #expect(set.repsRight == 9)
    }

    @Test func changingACompletedSetKeepsItsCompletionTimeAndIsSaved() throws {
        let bench = entry("Bench", true)
        let session = LoggingSession(workout: workout)
        let set = bench.sortedSets[0]
        session.select(set)

        session.changeWeight(to: 62.5)
        session.changeReps(\.reps, to: 8)

        #expect(set.completedAt == Self.started)
        let fresh = ModelContext(container)
        let stored = try #require(try fresh.fetch(FetchDescriptor<WorkoutSet>()).first { $0.id == set.id })
        #expect(stored.weight == 62.5)
        #expect(stored.reps == 8)
    }

    // MARK: Stale Workout

    static let threeHours: TimeInterval = 3 * 3600

    @Test func aWorkoutWithoutCompletedSetsIsStaleThreeHoursAfterItsStart() {
        entry("Bench", false)
        let session = LoggingSession(workout: workout)

        #expect(!session.isStale(at: Self.started.addingTimeInterval(Self.threeHours)))
        #expect(session.isStale(at: Self.started.addingTimeInterval(Self.threeHours + 1)))
    }

    @Test func theLastCompletedSetCountsAsActivity() {
        let bench = entry("Bench", true, true)
        bench.sortedSets[1].completedAt = Self.tap
        let session = LoggingSession(workout: workout)

        #expect(!session.isStale(at: Self.tap.addingTimeInterval(Self.threeHours)))
        #expect(session.isStale(at: Self.tap.addingTimeInterval(Self.threeHours + 1)))
    }

    @Test func resumingCountsAsActivityUntilTheSessionEnds() {
        entry("Bench", true)
        let session = LoggingSession(workout: workout)
        let resumed = Self.started.addingTimeInterval(4 * 3600)

        session.resume(at: resumed)

        #expect(!session.isStale(at: resumed.addingTimeInterval(Self.threeHours)))
        #expect(session.isStale(at: resumed.addingTimeInterval(Self.threeHours + 1)))
        #expect(LoggingSession(workout: workout).isStale(at: resumed.addingTimeInterval(60)))
    }

    @Test func theNextEntryFollowsTheCurrentOneAndTheLastHasNone() {
        let squat = entry("Squat", true)
        let bench = entry("Bench", true)
        let session = LoggingSession(workout: workout)
        session.select(squat)

        #expect(session.nextEntry == bench)

        session.select(bench)
        #expect(session.nextEntry == nil)
    }
}
