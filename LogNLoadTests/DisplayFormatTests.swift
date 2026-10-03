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

    @Test func agoIsADurationUnderADay() {
        #expect(DisplayFormat.ago(from: time(14, 10), to: time(17, 30)) == "3 h 20 min ago")
        #expect(DisplayFormat.ago(from: time(17, 30), to: time(17, 45)) == "15 min ago")
    }

    @Test func agoIsWholeDaysFromADay() {
        let before = time(17, 30)

        #expect(DisplayFormat.ago(from: before, to: before.addingTimeInterval(24 * 3600)) == "1 day ago")
        #expect(DisplayFormat.ago(from: before, to: before.addingTimeInterval(47 * 3600)) == "1 day ago")
        #expect(DisplayFormat.ago(from: before, to: before.addingTimeInterval(48 * 3600)) == "2 days ago")
    }

    // MARK: Prompt times

    @Test func aTimeTodayIsTheTimeAlone() {
        #expect(DisplayFormat.time(time(17, 42), now: time(21, 5), locale: Self.british) == "17:42")
    }

    @Test func aTimeOnAnotherDayHasTheWeekdayDayAndMonth() {
        let earlier = DateComponents(calendar: .current, year: 2026, month: 9, day: 22, hour: 17, minute: 42).date!

        #expect(DisplayFormat.time(earlier, now: time(9, 0), locale: Self.british) == "Tue 22 Sep, 17:42")
    }

    // MARK: Counts

    @Test func aNounAfterACountIsSingularOnlyForOne() {
        #expect(DisplayFormat.count(1, "Set") == "1 Set")
        #expect(DisplayFormat.count(0, "Exercise") == "0 Exercises")
        #expect(DisplayFormat.count(3, "target Set") == "3 target Sets")
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

    // MARK: History

    /// Weeks start on Monday, as in a British or Swedish Region.
    static let mondayCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = british
        calendar.firstWeekday = 2
        return calendar
    }()

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 17, _ minute: Int = 0) -> Date {
        DateComponents(calendar: Self.mondayCalendar, year: year, month: month, day: day, hour: hour, minute: minute).date!
    }

    func heading(_ start: Date) -> String {
        DisplayFormat.weekHeading(start, now: date(2026, 10, 2), locale: Self.british, calendar: Self.mondayCalendar)
    }

    @Test func theCurrentAndPreviousWeeksAreNamed() {
        #expect(heading(date(2026, 9, 28, 0)) == "This week")
        #expect(heading(date(2026, 9, 21, 0)) == "Last week")
    }

    /// `Date.IntervalFormatStyle` writes shared parts once and sets the dash between thin spaces.
    @Test func olderWeeksAreTheirDateRangeWithTheYearWhenAnyDayIsInAnotherYear() {
        #expect(heading(date(2026, 9, 14, 0)) == "14\u{2009}\u{2013}\u{2009}20 Sep")
        #expect(heading(date(2026, 8, 31, 0)) == "31 Aug\u{2009}\u{2013}\u{2009}6 Sep")
        #expect(heading(date(2025, 9, 15, 0)) == "15\u{2009}\u{2013}\u{2009}21 Sep 2025")
        #expect(heading(date(2025, 12, 29, 0)) == "29 Dec 2025\u{2009}\u{2013}\u{2009}4 Jan 2026")
    }

    @Test func workoutsAreGroupedIntoWeeksNewestFirst() {
        let sunday = Workout(startedAt: date(2026, 9, 27), endedAt: date(2026, 9, 27, 18))
        let monday = Workout(startedAt: date(2026, 9, 21), endedAt: date(2026, 9, 21, 18))
        let thisMonday = Workout(startedAt: date(2026, 9, 28), endedAt: date(2026, 9, 28, 18))

        let weeks = DisplayFormat.historyWeeks([thisMonday, sunday, monday], calendar: Self.mondayCalendar)

        #expect(weeks.map(\.start) == [date(2026, 9, 28, 0), date(2026, 9, 21, 0)])
        #expect(weeks.map(\.workouts) == [[thisMonday], [sunday, monday]])
    }

    @Test func aHistoryLineShowsTheStartDurationExercisesAndWorkingSets() {
        let workout = Workout(startedAt: date(2026, 9, 30, 17, 30), endedAt: date(2026, 9, 30, 18, 40))
        context.insert(workout)
        let entry = ExerciseEntry(workout: workout, exercise: exercise(), order: 0)
        _ = WorkoutSet(entry: entry, order: 0, isWarmUp: true, completedAt: .now)
        _ = WorkoutSet(entry: entry, order: 1, completedAt: .now)

        #expect(DisplayFormat.historyLine(workout, locale: Self.british, calendar: Self.mondayCalendar) == "17:30, 1 h 10 min \u{2013} 1 Exercise, 1 Set")
    }

    // MARK: Calendar

    func finished(_ start: Date, workingSets: Int = 1) -> Workout {
        let workout = Workout(startedAt: start, endedAt: start.addingTimeInterval(3600))
        context.insert(workout)
        let entry = ExerciseEntry(workout: workout, exercise: exercise(), order: 0)
        for order in 0..<workingSets { _ = WorkoutSet(entry: entry, order: order, completedAt: start) }
        _ = WorkoutSet(entry: entry, order: workingSets, isWarmUp: true, completedAt: start)
        return workout
    }

    @Test func aWorkoutsDateIsItsWeekdayDayAndMonth() {
        #expect(DisplayFormat.workoutDate(date(2026, 9, 30), locale: Self.british, calendar: Self.mondayCalendar) == "Wednesday 30 Sep")
    }

    @Test func theMonthIsHeadedWithItsNameAndYear() {
        #expect(DisplayFormat.monthHeading(date(2026, 9, 1, 0), locale: Self.british, calendar: Self.mondayCalendar) == "September 2026")
    }

    @Test func theMonthSummaryCountsItsWorkoutsAndWorkingSets() {
        let workouts = [finished(date(2026, 10, 1), workingSets: 2), finished(date(2026, 9, 30), workingSets: 3), finished(date(2026, 9, 2), workingSets: 1)]

        #expect(DisplayFormat.monthSummary(date(2026, 9, 1, 0), workouts: workouts, calendar: Self.mondayCalendar) == "2 Workouts, 4 Sets")
        #expect(DisplayFormat.monthSummary(date(2026, 8, 1, 0), workouts: workouts, calendar: Self.mondayCalendar) == "No Workouts")
    }

    @Test func theMonthGridStartsOnTheRegionsFirstWeekday() {
        let days = DisplayFormat.monthDays(date(2026, 9, 1, 0), calendar: Self.mondayCalendar)

        #expect(days.prefix(2).map { $0 == nil } == [true, false])
        #expect(days.compactMap(\.self).count == 30)
        #expect(days[1] == date(2026, 9, 1, 0))
    }

    @Test func pagingGoesToTheMonthsNewestWorkoutElseTheNearestOlderOne() {
        let october = finished(date(2026, 10, 1))
        let lateSeptember = finished(date(2026, 9, 30))
        let earlySeptember = finished(date(2026, 9, 2))
        let june = finished(date(2026, 6, 15))
        let workouts = [october, lateSeptember, earlySeptember, june]

        #expect(DisplayFormat.pagingTarget(date(2026, 9, 1, 0), workouts: workouts, calendar: Self.mondayCalendar) == lateSeptember)
        #expect(DisplayFormat.pagingTarget(date(2026, 8, 1, 0), workouts: workouts, calendar: Self.mondayCalendar) == june)
        #expect(DisplayFormat.pagingTarget(date(2026, 5, 1, 0), workouts: workouts, calendar: Self.mondayCalendar) == nil)
    }

    // MARK: Exercise page

    @Test func theDetailsLineShowsOnlyThePartsThatApply() {
        #expect(DisplayFormat.exerciseDetails(exercise(.machine)) == "Machine \u{2013} Loaded")
        #expect(DisplayFormat.exerciseDetails(exercise(.dumbbell, isUnilateral: true)) == "Dumbbell \u{2013} Loaded \u{2013} Unilateral \u{2013} kg per dumbbell")
        #expect(DisplayFormat.exerciseDetails(exercise(.bodyweight, loadType: .bodyweight)) == "Bodyweight \u{2013} Bodyweight")
        #expect(DisplayFormat.exerciseDetails(exercise(.kettlebell)) == "Kettlebell \u{2013} Loaded \u{2013} kg per kettlebell")
    }

    @Test func aShortDateHasTheYearOnlyOutsideTheCurrentYear() {
        #expect(DisplayFormat.shortDate(date(2026, 9, 28), now: Self.today, locale: Self.british) == "28 Sep")
        #expect(DisplayFormat.shortDate(date(2025, 12, 30), now: Self.today, locale: Self.british) == "30 Dec 2025")
    }

    @Test func theLockNoteNamesTheEquipmentLimit() {
        #expect(DisplayFormat.equipmentLimit(for: exercise(.dumbbell)) == "Equipment can only change between Dumbbell and Kettlebell.")
        #expect(DisplayFormat.equipmentLimit(for: exercise(.cable)) == "Equipment can't change to Dumbbell or Kettlebell.")
    }

    @Test func anExercisesHistoryIsGroupedIntoMonthsNewestFirst() {
        let squat = exercise()
        let entries = [date(2026, 9, 30), date(2026, 9, 2), date(2026, 8, 20)].map { start in
            let workout = Workout(startedAt: start, endedAt: start.addingTimeInterval(3600))
            context.insert(workout)
            return ExerciseEntry(workout: workout, exercise: squat, order: 0)
        }

        let months = DisplayFormat.historyMonths(entries, calendar: Self.mondayCalendar)

        #expect(months.map(\.month) == [date(2026, 9, 1, 0), date(2026, 8, 1, 0)])
        #expect(months.map(\.entries) == [[entries[0], entries[1]], [entries[2]]])
    }

    @Test func theMergeFilterNamesWhatItKeepsAndHowManyItHides() {
        #expect(DisplayFormat.mergeFilter(for: exercise(), hiddenCount: 3) == "Only Exercises with the same Load Type (Loaded), not unilateral, with weight as one total. 3 others are hidden.")
        #expect(DisplayFormat.mergeFilter(for: exercise(.dumbbell, isUnilateral: true), hiddenCount: 1) == "Only Exercises with the same Load Type (Loaded), unilateral, with weight per dumbbell or kettlebell. 1 other is hidden.")
        #expect(DisplayFormat.mergeFilter(for: exercise(.bodyweight, loadType: .bodyweight), hiddenCount: 0) == "Only Exercises with the same Load Type (Bodyweight), not unilateral, with weight as one total.")
    }
}
