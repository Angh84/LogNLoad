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

    @Test func pickingAnExerciseAlreadyInTheWorkoutShowsTheToast() throws {
        let squat = entry("Squat", false)
        let session = LoggingSession(workout: workout)
        session.add(exercise("Bench"))
        #expect(session.toast == nil)

        session.add(try #require(squat.exercise))

        #expect(session.toast == "Squat is already in this Workout")
    }

    @Test func aCreatedExerciseIsStoredAndAddedWithOneEmptyTargetSet() throws {
        let session = LoggingSession(workout: workout)
        let created = Exercise(name: "Cable Fly", equipment: .cable, muscleEmphases: [MuscleEmphasis(muscleGroup: .lowerChest, weight: 1)])

        session.create(created)

        let entry = try #require(workout.sortedEntries.last)
        #expect(entry.exercise == created)
        #expect(entry.sortedSets.map { [$0.weight, Double($0.reps)] } == [[0, 0]])
        #expect(session.currentEntry == entry)
        #expect(session.currentSet == entry.sortedSets.first)
        let fresh = ModelContext(container)
        #expect(try fresh.fetch(FetchDescriptor<Exercise>()).contains { $0.name == "Cable Fly" })
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

    // MARK: Shaping the Workout

    @Test func addSetMakesTheNewTargetSetCurrentAndIsSaved() throws {
        let bench = entry("Bench", true)
        let session = LoggingSession(workout: workout)

        session.addSet()

        let added = try #require(bench.sortedSets.last)
        #expect(bench.sortedSets.count == 2)
        #expect(session.currentSet == added)
        #expect(added.isTarget)
        let fresh = ModelContext(container)
        #expect(try fresh.fetchCount(FetchDescriptor<WorkoutSet>()) == 2)
    }

    @Test func deletingTheCurrentSetGoesToTheFirstTargetSet() throws {
        let bench = entry("Bench", true, false, false)
        let session = LoggingSession(workout: workout)
        let third = bench.sortedSets[2]
        session.select(third)

        session.delete(third)

        #expect(bench.sortedSets.count == 2)
        #expect(session.currentSet == bench.sortedSets[1])
        let fresh = ModelContext(container)
        #expect(try fresh.fetchCount(FetchDescriptor<WorkoutSet>()) == 2)
    }

    @Test func deletingTheLastTargetSetShowsTheNoTargetState() {
        let bench = entry("Bench", true, false)
        let session = LoggingSession(workout: workout)

        session.delete(bench.sortedSets[1])

        #expect(session.currentSet == nil)
        #expect(session.heading == "All 1 Set done")
    }

    @Test func deletingAnotherSetKeepsTheCurrentOne() {
        let bench = entry("Bench", true, false)
        let session = LoggingSession(workout: workout)
        let current = bench.sortedSets[1]

        session.delete(bench.sortedSets[0])

        #expect(session.currentSet == current)
    }

    @Test func removingTheCurrentEntryMakesTheNextOneCurrentAndDeletesItsSets() throws {
        let squat = entry("Squat", true)
        let bench = entry("Bench", true, false)
        let row = entry("Row", false)
        let session = LoggingSession(workout: workout)
        session.select(bench)

        session.remove(bench)

        #expect(workout.sortedEntries == [squat, row])
        #expect(session.currentEntry == row)
        #expect(session.currentSet == row.sortedSets.first)
        let fresh = ModelContext(container)
        #expect(try fresh.fetchCount(FetchDescriptor<WorkoutSet>()) == 2)
    }

    @Test func removingTheLastEntryMakesThePreviousOneCurrent() {
        let squat = entry("Squat", true)
        let bench = entry("Bench", false)
        let session = LoggingSession(workout: workout)
        session.select(bench)

        session.remove(bench)

        #expect(session.currentEntry == squat)
        #expect(session.currentSet == nil)
    }

    @Test func removingTheOnlyEntryLeavesTheEmptyWorkout() {
        let bench = entry("Bench", false)
        let session = LoggingSession(workout: workout)

        session.remove(bench)

        #expect(workout.sortedEntries.isEmpty)
        #expect(session.currentEntry == nil)
        #expect(session.heading == nil)
    }

    @Test func removeExerciseAsksOnlyWhenTheEntryHasCompletedSets() {
        let squat = entry("Squat", true, false)
        let bench = entry("Bench", false, false)
        let session = LoggingSession(workout: workout)

        #expect(session.requestRemoval(of: squat) == squat)
        #expect(workout.sortedEntries.contains(squat))

        #expect(session.requestRemoval(of: bench) == nil)
        #expect(!workout.sortedEntries.contains(bench))
    }

    @Test func removingAnotherEntryKeepsTheCurrentOne() {
        let squat = entry("Squat", false)
        let bench = entry("Bench", false)
        let session = LoggingSession(workout: workout)

        session.remove(bench)

        #expect(session.currentEntry == squat)
        #expect(session.currentSet == squat.sortedSets.first)
    }

    @Test func draggingASetReordersTheEntrysSetsAndIsSaved() throws {
        let bench = entry("Bench", true, false, false)
        let session = LoggingSession(workout: workout)
        let sets = bench.sortedSets

        session.moveSets(fromOffsets: [2], toOffset: 0)

        #expect(bench.sortedSets == [sets[2], sets[0], sets[1]])
        let fresh = ModelContext(container)
        let stored = try fresh.fetch(FetchDescriptor<WorkoutSet>(sortBy: [SortDescriptor(\.order)]))
        #expect(stored.map(\.id) == [sets[2], sets[0], sets[1]].map(\.id))
    }

    @Test func draggingAnEntryReordersTheWorkoutsEntries() {
        let squat = entry("Squat", true)
        let bench = entry("Bench", true)
        let row = entry("Row", false)
        let session = LoggingSession(workout: workout)

        session.moveEntries(fromOffsets: [0], toOffset: 3)

        #expect(workout.sortedEntries == [bench, row, squat])
    }

    @Test func markingASetAsWarmUpClearsItsRIRAndMarkingItWorkingLeavesItEmpty() throws {
        let bench = entry("Bench", true)
        let set = bench.sortedSets[0]
        set.rir = 2
        let session = LoggingSession(workout: workout)
        session.select(set)

        session.toggleWarmUp()
        #expect(set.isWarmUp)
        #expect(set.rir == nil)

        session.toggleWarmUp()
        #expect(!set.isWarmUp)
        #expect(set.rir == nil)
        #expect(set.completedAt == Self.started)
        let fresh = ModelContext(container)
        #expect(try fresh.fetch(FetchDescriptor<WorkoutSet>()).first?.isWarmUp == false)
    }

    @Test func theRIRChipChangesACompletedWorkingSetsRIRButNeverAWarmUpSets() {
        let bench = entry("Bench", true, true)
        bench.sortedSets[1].isWarmUp = true
        let session = LoggingSession(workout: workout)

        session.select(bench.sortedSets[0])
        session.changeRIR(to: 4)
        session.changeRIR(to: nil)
        #expect(bench.sortedSets[0].rir == nil)
        session.changeRIR(to: 1)
        #expect(bench.sortedSets[0].rir == 1)

        session.select(bench.sortedSets[1])
        session.changeRIR(to: 3)
        #expect(bench.sortedSets[1].rir == nil)
    }

    @Test func namesAndNotesTypedWhileLoggingAreStoredTrimmed() throws {
        let bench = entry("Bench", false)
        let set = bench.sortedSets[0]
        let session = LoggingSession(workout: workout)

        session.changeWorkoutName(to: "  Push day ")
        session.changeWorkoutNote(to: " \n ")
        session.changeNote(to: " Wide grip\n", of: bench)
        session.changeNote(to: "  Paused  ", of: set)

        let fresh = ModelContext(container)
        let storedWorkout = try #require(try fresh.fetch(FetchDescriptor<Workout>()).first)
        #expect(storedWorkout.name == "Push day")
        #expect(storedWorkout.note == nil)
        #expect(try fresh.fetch(FetchDescriptor<ExerciseEntry>()).first?.note == "Wide grip")
        #expect(try fresh.fetch(FetchDescriptor<WorkoutSet>()).first?.note == "Paused")
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

    // MARK: Edit mode

    static let earlier = DateComponents(calendar: .current, year: 2026, month: 9, day: 28, hour: 17).date!

    /// A finished Workout two days before the Active one, with one Entry per list of Set weights.
    func finishedWorkout(_ weightsPerEntry: [Double]...) throws -> Workout {
        let finished = Workout(startedAt: Self.earlier, endedAt: Self.earlier.addingTimeInterval(3600))
        context.insert(finished)
        for (order, weights) in weightsPerEntry.enumerated() {
            let entry = ExerciseEntry(workout: finished, exercise: exercise("Exercise \(order)"), order: order)
            for (setOrder, weight) in weights.enumerated() {
                _ = WorkoutSet(entry: entry, order: setOrder, weight: weight, reps: 10, completedAt: Self.earlier)
            }
        }
        try context.save()
        return finished
    }

    func stored(_ workout: Workout) throws -> Workout? {
        let id = workout.id
        return try ModelContext(container).fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.id == id })).first
    }

    @Test func anEditSessionOpensOnTheFirstSetInItsOwnContext() throws {
        let finished = try finishedWorkout([60, 70], [40])
        let session = try #require(LoggingSession.editing(finished))

        #expect(session.isEditing)
        #expect(session.workout.modelContext !== context)
        #expect(session.currentEntry == session.workout.sortedEntries.first)
        #expect(session.currentSet?.weight == 60)
    }

    @Test func editsWaitForDoneAndDoneSavesThem() throws {
        let finished = try finishedWorkout([60])
        let session = try #require(LoggingSession.editing(finished))

        session.changeWeight(to: 65)
        #expect(try stored(finished)?.sortedEntries.first?.sortedSets.first?.weight == 60)

        session.saveEdit()
        #expect(try stored(finished)?.sortedEntries.first?.sortedSets.first?.weight == 65)
    }

    @Test func cancelDiscardsTheEditAndLeavesTheActiveWorkoutAlone() throws {
        entry("Bench", false)
        try context.save()
        let finished = try finishedWorkout([60])
        let active = LoggingSession(workout: workout)
        let session = try #require(LoggingSession.editing(finished))
        workout.name = "Unsaved in the Active Workout"

        session.changeWeight(to: 65)
        session.cancelEdit()

        #expect(try stored(finished)?.sortedEntries.first?.sortedSets.first?.weight == 60)
        #expect(workout.name == "Unsaved in the Active Workout")
        #expect(active.currentEntry?.exercise?.name == "Bench")
    }

    @Test func doneChecksTheTimesInTheSpecsOrder() throws {
        let finished = try finishedWorkout([60])
        let session = try #require(LoggingSession.editing(finished))
        let now = Self.started.addingTimeInterval(3600)

        session.workout.endedAt = session.workout.startedAt
        #expect(session.doneProblem(now: now) == .endNotAfterStart)

        session.workout.endedAt = now.addingTimeInterval(60)
        #expect(session.doneProblem(now: now) == .endInFuture)

        session.workout.endedAt = Self.earlier.addingTimeInterval(1800)
        #expect(session.doneProblem(now: now) == nil)
    }

    @Test func doneRefusesAnOverlapWithAnotherWorkoutTheActiveOneIncluded() throws {
        let finished = try finishedWorkout([60])
        let other = Workout(startedAt: Self.earlier.addingTimeInterval(-7200), endedAt: Self.earlier.addingTimeInterval(-3600))
        context.insert(other)
        try context.save()
        let session = try #require(LoggingSession.editing(finished))
        let now = Self.started.addingTimeInterval(3600)

        session.workout.startedAt = Self.earlier.addingTimeInterval(-5400)
        #expect(session.doneProblem(now: now)?.overlapping?.id == other.id)

        session.workout.startedAt = Self.earlier
        session.workout.endedAt = Self.started.addingTimeInterval(60)
        #expect(session.doneProblem(now: now)?.overlapping?.id == workout.id)
    }

    @Test func doneOffersToDeleteAWorkoutLeftWithoutSets() throws {
        let finished = try finishedWorkout([60])
        let session = try #require(LoggingSession.editing(finished))

        session.delete(try #require(session.currentSet))

        #expect(session.doneProblem(now: Self.started) == .noSets)
    }

    @Test func savingDropsEntriesLeftWithoutSets() throws {
        let finished = try finishedWorkout([60], [40])
        let session = try #require(LoggingSession.editing(finished))
        session.select(session.workout.sortedEntries[1])

        session.delete(try #require(session.currentSet))
        session.saveEdit()

        #expect(try stored(finished)?.sortedEntries.count == 1)
    }

    @Test func deletingTheCurrentSetWhileEditingGoesToTheFollowingThenThePreviousSet() throws {
        let finished = try finishedWorkout([60, 70, 80])
        let session = try #require(LoggingSession.editing(finished))
        let sets = session.workout.sortedEntries[0].sortedSets
        session.select(sets[1])

        session.delete(sets[1])
        #expect(session.currentSet == sets[2])
        #expect(session.workout.sortedEntries[0].sortedSets.count == 2)

        session.delete(sets[2])
        #expect(session.currentSet == sets[0])

        session.delete(sets[0])
        #expect(session.currentSet == nil)
        #expect(session.heading == "No Sets")
    }

    @Test func nextSetWhileEditingIsTheFollowingSet() throws {
        let finished = try finishedWorkout([60, 70])
        let session = try #require(LoggingSession.editing(finished))

        #expect(session.followingSet?.weight == 70)
        session.nextSet()
        #expect(session.currentSet?.weight == 70)
        #expect(session.followingSet == nil)
    }

    @Test func anExercisePickedWhileEditingJoinsTheEditAndIsSavedWithIt() throws {
        let finished = try finishedWorkout([60])
        let session = try #require(LoggingSession.editing(finished))
        let curl = exercise("Curl")
        try context.save()

        session.add(curl)
        session.addSet()
        session.saveEdit()

        let saved = try #require(try stored(finished))
        #expect(saved.sortedEntries.map { $0.exercise?.name } == ["Exercise 0", "Curl"])
        #expect(saved.sortedEntries[1].sortedSets.count == 2)
        #expect(saved.sortedEntries[1].sortedSets.allSatisfy { $0.completedAt == nil && !$0.isTarget })
    }

    @Test func doneReachesTheMainContextsCopyOfTheWorkout() throws {
        let finished = try finishedWorkout([60])
        let session = try #require(LoggingSession.editing(finished))

        session.changeWeight(to: 65)
        session.changeWorkoutName(to: "Legs")
        session.saveEdit()

        #expect(finished.name == "Legs")
        #expect(finished.sortedEntries.first?.sortedSets.first?.weight == 65)
    }

    @Test func doneReachesTheMainContextsExerciseHistory() throws {
        let finished = try finishedWorkout([60])
        let removed = try #require(finished.sortedEntries.first?.exercise)
        let curl = exercise("Curl")
        try context.save()
        #expect(removed.lastPerformance?.map(\.weight) == [60])
        let session = try #require(LoggingSession.editing(finished))

        session.remove(try #require(session.currentEntry))
        session.add(curl)
        session.changeWeight(to: 25)
        session.saveEdit()

        #expect(removed.lastPerformance == nil)
        #expect(curl.lastPerformance?.map(\.weight) == [25])
    }

    @Test func anExerciseCreatedWhileEditingHoldsItsNameBeforeDone() throws {
        let finished = try finishedWorkout([60])
        let session = try #require(LoggingSession.editing(finished))
        let editContext = try #require(session.workout.modelContext)

        session.create(Exercise(name: "Zercher Squat", equipment: .barbell, muscleEmphases: [MuscleEmphasis(muscleGroup: .quads, weight: 1)]))

        #expect(Exercise.named("zercher squat", in: editContext)?.name == "Zercher Squat")
    }
}
