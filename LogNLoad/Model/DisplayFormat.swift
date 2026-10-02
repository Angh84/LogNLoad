import Foundation

/// How values are written wherever they appear (docs/spec/README.md, Display formats).
enum DisplayFormat {
    /// Up to 2 decimals, trailing zeros dropped: "62.5 kg".
    static func weight(_ kg: Double, locale: Locale = .current) -> String {
        kg.formatted(.number.precision(.fractionLength(0...2)).locale(locale)) + " kg"
    }

    /// "62.5 kg x 10", "BW+10 kg x 8", "14 kg x 10/9", with the multiplication sign.
    static func set(_ set: WorkoutSet, of exercise: Exercise, locale: Locale = .current) -> String {
        load(set.weight, of: exercise, locale: locale) + " \u{D7} " + reps(of: set, exercise)
    }

    /// The Sets in order, consecutive Sets with the same weight and Warm-up status sharing one group:
    /// "W 20 kg x 10, 10 / 62.5 kg x 10, 9, 8". Never re-sorted.
    static func summary(of sets: [WorkoutSet], of exercise: Exercise, locale: Locale = .current) -> String {
        var groups: [(first: WorkoutSet, reps: [String])] = []
        for set in sets {
            if let last = groups.last, last.first.weight == set.weight, last.first.isWarmUp == set.isWarmUp {
                groups[groups.count - 1].reps.append(reps(of: set, exercise))
            } else {
                groups.append((set, [reps(of: set, exercise)]))
            }
        }
        return groups.map { group in
            (group.first.isWarmUp ? "W " : "") + load(group.first.weight, of: exercise, locale: locale)
                + " \u{D7} " + group.reps.joined(separator: ", ")
        }
        .joined(separator: " / ")
    }

    /// "28 Sep: 62.5 kg x 10, 9, 8" from the Working Sets, all Sets when every one is a Warm-up Set,
    /// or "Not logged yet". The year is shown when it isn't the current one.
    static func lastPerformance(
        of exercise: Exercise,
        now: Date = .now,
        locale: Locale = .current,
        calendar: Calendar = .current
    ) -> String {
        guard let sets = exercise.lastPerformance, let date = sets.first?.entry?.workout?.startedAt else {
            return "Not logged yet"
        }
        var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).day().month(.abbreviated)
        if !calendar.isDate(date, equalTo: now, toGranularity: .year) { style = style.year() }
        let working = sets.filter(\.isWorkingSet)
        return date.formatted(style) + ": " + summary(of: working.isEmpty ? sets : working, of: exercise, locale: locale)
    }

    /// "45 min", "1 h 10 min", "2 h", from both times truncated to the minute so it matches the times shown.
    static func duration(from start: Date, to end: Date) -> String {
        let (hours, rest) = minutes(from: start, to: end).quotientAndRemainder(dividingBy: 60)
        switch (hours, rest) {
        case (0, _): return "\(rest) min"
        case (_, 0): return "\(hours) h"
        default: return "\(hours) h \(rest) min"
        }
    }

    /// A prompt's `hh:mm`: "17:42" today, otherwise "Tue 22 Sep, 17:42".
    static func time(_ date: Date, now: Date = .now, locale: Locale = .current, calendar: Calendar = .current) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        let time = date.formatted(style.hour().minute())
        guard !calendar.isDate(date, inSameDayAs: now) else { return time }
        return date.formatted(style.weekday(.abbreviated).day().month(.abbreviated)) + ", " + time
    }

    /// "1 Set", "2 Sets": the noun is singular only for a count of 1.
    static func count(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }

    /// "3 h 20 min ago" under 24 hours, then whole days: "1 day ago", "2 days ago".
    static func ago(from then: Date, to now: Date) -> String {
        let days = minutes(from: then, to: now) / (24 * 60)
        return (days == 0 ? duration(from: then, to: now) : count(days, "day")) + " ago"
    }

    /// The History list's week sections: finished Workouts, newest first, grouped by the calendar's week, whose
    /// first weekday follows the Region.
    static func historyWeeks(_ workouts: [Workout], calendar: Calendar = .current) -> [(start: Date, workouts: [Workout])] {
        var weeks: [(start: Date, workouts: [Workout])] = []
        for workout in workouts {
            guard let startedAt = workout.startedAt, let start = calendar.dateInterval(of: .weekOfYear, for: startedAt)?.start else { continue }
            if weeks.last?.start == start {
                weeks[weeks.count - 1].workouts.append(workout)
            } else {
                weeks.append((start, [workout]))
            }
        }
        return weeks
    }

    /// "This week", "Last week", else the range ("14-20 Sep"), with the year when any day is outside the current one.
    static func weekHeading(_ start: Date, now: Date = .now, locale: Locale = .current, calendar: Calendar = .current) -> String {
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start
        if start == thisWeek { return "This week" }
        if let thisWeek, start == calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek) { return "Last week" }
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        var style = Date.IntervalFormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).day().month(.abbreviated)
        if ![start, end].allSatisfy({ calendar.isDate($0, equalTo: now, toGranularity: .year) }) { style = style.year() }
        return (start..<end).formatted(style)
    }

    /// "17:30, 1 h 10 min - 5 Exercises, 14 Sets": the start time, duration, Exercise count and Working Set count.
    static func historyLine(_ workout: Workout, locale: Locale = .current, calendar: Calendar = .current) -> String {
        guard let start = workout.startedAt, let end = workout.endedAt else { return "" }
        let time = start.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).hour().minute())
        return "\(time), \(duration(from: start, to: end)) \u{2013} "
            + "\(count(workout.sortedEntries.count, "Exercise")), \(count(workout.workingSetCount, "Set"))"
    }

    /// A Workout's day: "Wednesday 30 Sep", the title of an unnamed Workout and the edit banner's date.
    static func workoutDate(_ date: Date, locale: Locale = .current, calendar: Calendar = .current) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.wide).day().month(.abbreviated))
    }

    /// The month grid's heading: "September 2026".
    static func monthHeading(_ month: Date, locale: Locale = .current, calendar: Calendar = .current) -> String {
        month.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide).year())
    }

    /// "N Workouts, N Sets" for the Workouts started in the month, Working Sets only; "No Workouts" without any.
    static func monthSummary(_ month: Date, workouts: [Workout], calendar: Calendar = .current) -> String {
        let inMonth = workouts.filter { $0.startedAt.map { calendar.isDate($0, equalTo: month, toGranularity: .month) } ?? false }
        guard !inMonth.isEmpty else { return "No Workouts" }
        return workoutCounts(inMonth)
    }

    /// "N Workouts, N Sets", Working Sets only: the week and month headers.
    static func workoutCounts(_ workouts: [Workout]) -> String {
        "\(count(workouts.count, "Workout")), \(count(workouts.map(\.workingSetCount).reduce(0, +), "Set"))"
    }

    /// The month grid's cells: a blank for each weekday before the 1st, by the calendar's first weekday, then each day.
    static func monthDays(_ month: Date, calendar: Calendar = .current) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let leading = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        let dayCount = calendar.range(of: .day, in: .month, for: month)?.count ?? 0
        let days = (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
        return Array(repeating: nil, count: leading) + days
    }

    /// Where paging to `month` scrolls the list: its newest Workout, else the nearest older one. `workouts` come
    /// newest first.
    static func pagingTarget(_ month: Date, workouts: [Workout], calendar: Calendar = .current) -> Workout? {
        guard let end = calendar.dateInterval(of: .month, for: month)?.end else { return nil }
        return workouts.first { ($0.startedAt ?? .distantFuture) < end }
    }

    /// The weight stepper's label, by Load Type, then by weight convention.
    static func weightLabel(for exercise: Exercise) -> String {
        switch (exercise.loadType, exercise.equipment) {
        case (.assisted, _): "Assistance"
        case (.bodyweight, _): "Added weight"
        case (.loaded, .dumbbell): "Weight per dumbbell"
        case (.loaded, .kettlebell): "Weight per kettlebell"
        case (.loaded, _): "Weight"
        }
    }

    /// "0" to "3", and "Easy" for 4 or more in reserve.
    static func rir(_ rir: Int) -> String {
        rir >= 4 ? "Easy" : "\(rir)"
    }

    /// The weight as its Load Type reads it.
    private static func load(_ kg: Double, of exercise: Exercise, locale: Locale) -> String {
        switch exercise.loadType {
        case .loaded: weight(kg, locale: locale)
        case .bodyweight: kg == 0 ? "BW" : "BW+" + weight(kg, locale: locale)
        case .assisted: kg == 0 ? "BW" : "BW-" + weight(kg, locale: locale)
        }
    }

    /// Minutes between both times, each truncated to the minute.
    private static func minutes(from start: Date, to end: Date) -> Int {
        func minute(_ date: Date) -> Int { Int((date.timeIntervalSinceReferenceDate / 60).rounded(.down)) }
        return minute(end) - minute(start)
    }

    private static func reps(of set: WorkoutSet, _ exercise: Exercise) -> String {
        exercise.isUnilateral ? "\(set.repsLeft)/\(set.repsRight)" : "\(set.reps)"
    }
}
