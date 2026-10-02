import Foundation
import SwiftData
import Testing
@testable import LogNLoad

/// The display formats in docs/spec/README.md. "x" in the spec is the multiplication sign.
@MainActor
struct DisplayFormatTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    static let british = Locale(identifier: "en_GB")
    static let swedish = Locale(identifier: "sv_SE")

    init() throws {
        container = try .logNLoad(inMemory: true)
    }

    func exercise(_ equipment: Equipment = .barbell, loadType: LoadType = .loaded, isUnilateral: Bool = false) -> Exercise {
        let exercise = Exercise(name: "Test", equipment: equipment, loadType: loadType, isUnilateral: isUnilateral, muscleEmphases: [MuscleEmphasis(muscleGroup: .quads, weight: 1)])
        context.insert(exercise)
        return exercise
    }

    func set(_ weight: Double, _ reps: Int, left: Int = 0, right: Int = 0, warmUp: Bool = false) -> WorkoutSet {
        let workout = Workout(startedAt: .now)
        context.insert(workout)
        let entry = ExerciseEntry(workout: workout, exercise: exercise(), order: 0)
        return WorkoutSet(entry: entry, order: 0, weight: weight, reps: reps, repsLeft: left, repsRight: right, isWarmUp: warmUp)
    }

    func oneSet(_ set: WorkoutSet, of exercise: Exercise) -> String {
        DisplayFormat.set(set, of: exercise, locale: Self.british)
    }

    // MARK: Weight

    @Test(arguments: [(30.0, "30 kg"), (62.5, "62.5 kg"), (61.25, "61.25 kg"), (0, "0 kg")])
    func weightHasUpToTwoDecimalsWithoutTrailingZeros(kg: Double, text: String) {
        #expect(DisplayFormat.weight(kg, locale: Self.british) == text)
    }

    @Test func weightUsesTheRegionsDecimalSeparator() {
        #expect(DisplayFormat.weight(62.5, locale: Self.swedish) == "62,5 kg")
    }

    // MARK: One Set

    @Test func aLoadedSetIsItsWeightTimesItsReps() {
        #expect(oneSet(set(62.5, 10), of: exercise()) == "62.5 kg \u{D7} 10")
    }

    @Test func aBodyweightSetShowsTheAddedLoad() {
        let pullUp = exercise(.bodyweight, loadType: .bodyweight)

        #expect(oneSet(set(0, 12), of: pullUp) == "BW \u{D7} 12")
        #expect(oneSet(set(10, 8), of: pullUp) == "BW+10 kg \u{D7} 8")
    }

    @Test func anAssistedSetShowsTheAssistance() {
        let dip = exercise(.machine, loadType: .assisted)

        #expect(oneSet(set(30, 8), of: dip) == "BW-30 kg \u{D7} 8")
        #expect(oneSet(set(0, 8), of: dip) == "BW \u{D7} 8")
    }

    @Test func aDumbbellSetShowsTheWeightPerImplement() {
        #expect(oneSet(set(24, 10), of: exercise(.dumbbell)) == "24 kg \u{D7} 10")
    }

    @Test func aUnilateralSetShowsLeftThenRightAlsoWhenEqual() {
        let curl = exercise(.dumbbell, isUnilateral: true)

        #expect(oneSet(set(14, 0, left: 10, right: 9), of: curl) == "14 kg \u{D7} 10/9")
        #expect(oneSet(set(14, 0, left: 10, right: 10), of: curl) == "14 kg \u{D7} 10/10")
    }

    // MARK: Compact Set summary

    func summary(_ sets: [WorkoutSet], of exercise: Exercise) -> String {
        DisplayFormat.summary(of: sets, of: exercise, locale: Self.british)
    }

    @Test func consecutiveSetsWithTheSameWeightAndWarmUpStatusShareAGroup() {
        let sets = [
            set(20, 10, warmUp: true), set(20, 10, warmUp: true), set(40, 5, warmUp: true),
            set(62.5, 10), set(62.5, 9), set(62.5, 8),
        ]

        #expect(summary(sets, of: exercise()) == "W 20 kg \u{D7} 10, 10 / W 40 kg \u{D7} 5 / 62.5 kg \u{D7} 10, 9, 8")
    }

    @Test func theSummaryIsNeverResorted() {
        let returning = [set(60, 10), set(62.5, 8), set(60, 10)]
        let lateWarmUp = [set(62.5, 10), set(20, 10, warmUp: true)]

        #expect(summary(returning, of: exercise()) == "60 kg \u{D7} 10 / 62.5 kg \u{D7} 8 / 60 kg \u{D7} 10")
        #expect(summary(lateWarmUp, of: exercise()) == "62.5 kg \u{D7} 10 / W 20 kg \u{D7} 10")
    }

    @Test func aWarmUpAndAWorkingSetAtTheSameWeightAreSeparateGroups() {
        let sets = [set(20, 10, warmUp: true), set(20, 10)]

        #expect(summary(sets, of: exercise()) == "W 20 kg \u{D7} 10 / 20 kg \u{D7} 10")
    }

    @Test func theSummaryUsesTheLoadTypeAndBothSides() {
        let lunge = [set(20, 0, left: 10, right: 9), set(20, 0, left: 9, right: 9)]
        let pullUps = [set(0, 12), set(0, 10), set(5, 8)]

        #expect(summary(lunge, of: exercise(.dumbbell, isUnilateral: true)) == "20 kg \u{D7} 10/9, 9/9")
        #expect(summary(pullUps, of: exercise(.bodyweight, loadType: .bodyweight)) == "BW \u{D7} 12, 10 / BW+5 kg \u{D7} 8")
    }

    // MARK: Last Performance line

    static let today = DateComponents(calendar: .current, year: 2026, month: 10, day: 2, hour: 12).date!

    /// Logs a finished Workout started on `date` with one completed Set per (weight, reps, warm-up).
    func log(_ exercise: Exercise, on date: Date, _ sets: [(Double, Int, Bool)]) {
        let workout = Workout(startedAt: date, endedAt: date.addingTimeInterval(3600))
        context.insert(workout)
        let entry = ExerciseEntry(workout: workout, exercise: exercise, order: 0)
        for (order, set) in sets.enumerated() {
            _ = WorkoutSet(entry: entry, order: order, weight: set.0, reps: set.1, isWarmUp: set.2, completedAt: date)
        }
    }

    func lastPerformance(of exercise: Exercise) -> String {
        DisplayFormat.lastPerformance(of: exercise, now: Self.today, locale: Self.british)
    }

    @Test func theLastPerformanceLineShowsTheDateAndTheWorkingSets() {
        let bench = exercise()
        let date = DateComponents(calendar: .current, year: 2026, month: 9, day: 28, hour: 17).date!
        log(bench, on: date, [(20, 10, true), (62.5, 10, false), (62.5, 9, false), (62.5, 8, false)])

        #expect(lastPerformance(of: bench) == "28 Sep: 62.5 kg \u{D7} 10, 9, 8")
    }

    @Test func theLastPerformanceLineShowsWarmUpSetsWhenThereAreNoWorkingSets() {
        let bench = exercise()
        let date = DateComponents(calendar: .current, year: 2026, month: 9, day: 28, hour: 17).date!
        log(bench, on: date, [(20, 10, true), (20, 10, true)])

        #expect(lastPerformance(of: bench) == "28 Sep: W 20 kg \u{D7} 10, 10")
    }

    @Test func theLastPerformanceDateHasTheYearWhenItIsNotTheCurrentYear() {
        let bench = exercise()
        let date = DateComponents(calendar: .current, year: 2025, month: 12, day: 30, hour: 17).date!
        log(bench, on: date, [(60, 10, false)])

        #expect(lastPerformance(of: bench) == "30 Dec 2025: 60 kg \u{D7} 10")
    }

    @Test func anExerciseWithoutLastPerformanceIsNotLoggedYet() {
        #expect(lastPerformance(of: exercise()) == "Not logged yet")
    }

    // MARK: Durations

    func time(_ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        DateComponents(calendar: .current, year: 2026, month: 9, day: 30, hour: hour, minute: minute, second: second).date!
    }

    @Test func durationsUnderAnHourAreMinutes() {
        #expect(DisplayFormat.duration(from: time(17, 30), to: time(18, 15)) == "45 min")
        #expect(DisplayFormat.duration(from: time(17, 30, 10), to: time(17, 30, 50)) == "0 min")
    }

    @Test func durationsFromAnHourAreHoursAndMinutes() {
        #expect(DisplayFormat.duration(from: time(17, 30), to: time(18, 40)) == "1 h 10 min")
        #expect(DisplayFormat.duration(from: time(17, 0), to: time(19, 0)) == "2 h")
    }

    @Test func durationsMatchTheTimesShownByTruncatingBothToTheMinute() {
        #expect(DisplayFormat.duration(from: time(17, 30, 59), to: time(18, 40, 1)) == "1 h 10 min")
    }

    // MARK: Labels

    @Test func theWeightLabelFollowsTheLoadTypeAndWeightConvention() {
        #expect(DisplayFormat.weightLabel(for: exercise(.barbell)) == "Weight")
        #expect(DisplayFormat.weightLabel(for: exercise(.dumbbell)) == "Weight per dumbbell")
        #expect(DisplayFormat.weightLabel(for: exercise(.kettlebell)) == "Weight per kettlebell")
        #expect(DisplayFormat.weightLabel(for: exercise(.bodyweight, loadType: .bodyweight)) == "Added weight")
        #expect(DisplayFormat.weightLabel(for: exercise(.machine, loadType: .assisted)) == "Assistance")
    }

    @Test func rirFourReadsEasy() {
        #expect([0, 1, 2, 3, 4].map(DisplayFormat.rir) == ["0", "1", "2", "3", "Easy"])
    }
}
