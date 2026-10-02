import Foundation
import Observation
import SwiftData
import SwiftUI

/// The logging screen's state for the Active Workout. The current Entry and Set live only here,
/// never in the store, so a relaunch reopens on the first target Set.
@MainActor @Observable
final class LoggingSession {
    let workout: Workout
    private(set) var currentEntry: ExerciseEntry?
    /// Empty when the current Entry has no target Set left.
    private(set) var currentSet: WorkoutSet?
    /// The "Reps in reserve?" panel for the Working Set just completed.
    private(set) var isAskingRIR = false
    /// Up right after "Start Workout", and from the "+" chip and "Add Exercise".
    var isPickerPresented = false
    /// The last Resume tap on the stale prompt. Kept in memory only, so a relaunch soon after Resume asks again.
    private var resumedAt: Date?
    /// When the stale prompt came up, while it is up.
    var stalePromptAt: Date?

    init(workout: Workout) {
        self.workout = workout
        let entries = workout.sortedEntries
        currentEntry = entries.first { $0.firstTargetSet != nil } ?? entries.last
        currentSet = currentEntry?.firstTargetSet
    }

    /// Appends the Exercise's Entry, or goes to it when it is already in the Workout.
    func add(_ exercise: Exercise) {
        let entry = workout.add(exercise)
        save()
        select(entry)
    }

    /// Makes the Entry current, on its first target Set.
    func select(_ entry: ExerciseEntry) {
        currentEntry = entry
        currentSet = entry.firstTargetSet
        isAskingRIR = false
    }

    /// Makes a Set of the current Entry current, from the Sets log.
    func select(_ set: WorkoutSet) {
        currentSet = set
        isAskingRIR = false
    }

    /// Completes the current Set as it is. A Working Set then asks for its RIR; a Warm-up Set moves on.
    func complete(at date: Date) {
        guard let currentSet else { return }
        currentSet.completedAt = date
        save()
        if currentSet.isWorkingSet {
            isAskingRIR = true
        } else {
            moveToFirstTargetSet()
        }
    }

    /// Answers the RIR panel, where nil is Skip, and moves on.
    func recordRIR(_ rir: Int?) {
        currentSet?.rir = rir
        save()
        moveToFirstTargetSet()
    }

    /// Makes the current Set a target again, keeping its values.
    func undoCompletion() {
        currentSet?.completedAt = nil
        save()
    }

    /// Sets the current Set's weight in kg, to 2 decimals and never below 0. Keeps `completedAt`.
    func changeWeight(to kg: Double) {
        guard kg.isFinite else { return }
        currentSet?.weight = (max(kg, 0) * 100).rounded() / 100
        save()
    }

    /// Sets `reps`, `repsLeft` or `repsRight` of the current Set, never below 0. Keeps `completedAt`.
    func changeReps(_ reps: ReferenceWritableKeyPath<WorkoutSet, Int>, to count: Int) {
        currentSet?[keyPath: reps] = max(count, 0)
        save()
    }

    /// The "Warm-up" chip. A Working Set whose RIR panel is up is no longer asked once it is a Warm-up Set.
    func toggleWarmUp() {
        guard let currentSet else { return }
        currentSet.setWarmUp(!currentSet.isWarmUp)
        if currentSet.isWarmUp { isAskingRIR = false }
        save()
    }

    /// The RIR chip on a Completed Working Set, where nil clears it.
    func changeRIR(to rir: Int?) {
        guard let currentSet, currentSet.isWorkingSet else { return }
        currentSet.rir = rir
        save()
    }

    func changeWorkoutName(to text: String) {
        workout.name = trimmed(text)
        save()
    }

    func changeWorkoutNote(to text: String) {
        workout.note = trimmed(text)
        save()
    }

    /// The Entry note, from the Exercise "..." menu.
    func changeNote(to text: String, of entry: ExerciseEntry) {
        entry.note = trimmed(text)
        save()
    }

    /// The Set note, from the "Set note" chip.
    func changeNote(to text: String, of set: WorkoutSet) {
        set.note = trimmed(text)
        save()
    }

    /// "Add Set": appends a target Working Set to the current Entry and makes it current.
    func addSet() {
        guard let currentEntry else { return }
        let set = currentEntry.addSet()
        save()
        select(set)
    }

    /// Deletes a Set of the current Entry. When it was current, the Entry's first target Set becomes current.
    func delete(_ set: WorkoutSet) {
        let wasCurrent = set == currentSet
        workout.modelContext?.delete(set)
        save()
        if wasCurrent { moveToFirstTargetSet() }
    }

    /// "Remove Exercise" removes an Entry without Completed Sets at once. One with Completed Sets is returned
    /// for the "Remove <name>?" confirm, which then calls `remove(_:)`.
    func requestRemoval(of entry: ExerciseEntry) -> ExerciseEntry? {
        guard !entry.hasCompletedSet else { return entry }
        remove(entry)
        return nil
    }

    /// Deletes the Entry and its Sets. When it was current, the next Entry becomes current,
    /// else the previous one, else the empty Workout.
    func remove(_ entry: ExerciseEntry) {
        let entries = workout.sortedEntries
        guard let index = entries.firstIndex(of: entry) else { return }
        let neighbour = index + 1 < entries.count ? entries[index + 1] : index > 0 ? entries[index - 1] : nil
        let wasCurrent = entry == currentEntry
        workout.modelContext?.delete(entry)
        save()
        guard wasCurrent else { return }
        if let neighbour {
            select(neighbour)
        } else {
            currentEntry = nil
            currentSet = nil
            isAskingRIR = false
        }
    }

    /// Drag to reorder in the Sets log: renumbers the current Entry's Sets in their new order.
    func moveSets(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard let currentEntry else { return }
        var sets = currentEntry.sortedSets
        sets.move(fromOffsets: source, toOffset: destination)
        for (order, set) in sets.enumerated() { set.order = order }
        save()
    }

    /// Drag to reorder in the overview sheet: renumbers the Entries in their new order.
    func moveEntries(fromOffsets source: IndexSet, toOffset destination: Int) {
        var entries = workout.sortedEntries
        entries.move(fromOffsets: source, toOffset: destination)
        for (order, entry) in entries.enumerated() { entry.order = order }
        save()
    }

    /// The Entry's first target Set, or its no-target state when none is left.
    func nextSet() {
        moveToFirstTargetSet()
    }

    private func moveToFirstTargetSet() {
        currentSet = currentEntry?.firstTargetSet
        isAskingRIR = false
    }

    /// Whether the stale prompt is due: the last activity (the last `completedAt`, `startedAt` or the last
    /// Resume tap) is more than 3 hours before `now`.
    func isStale(at now: Date) -> Bool {
        let activity = [workout.lastCompletedAt, workout.startedAt, resumedAt].compactMap(\.self).max() ?? now
        return now.timeIntervalSince(activity) > 3 * 3600
    }

    /// Resume on the stale prompt.
    func resume(at date: Date) {
        resumedAt = date
    }

    func finish(at end: Date) {
        do {
            try workout.finish(at: end)
        } catch {
            fatalError("Could not finish the Workout: \(error)")
        }
    }

    func discard() {
        do {
            try workout.discard()
        } catch {
            fatalError("Could not discard the Workout: \(error)")
        }
    }

    /// The Entry after the current one, for "Next: <Exercise>". Empty on the last Entry.
    var nextEntry: ExerciseEntry? {
        let entries = workout.sortedEntries
        guard let index = entries.firstIndex(where: { $0 == currentEntry }), index + 1 < entries.count else { return nil }
        return entries[index + 1]
    }

    /// The card's heading, also the pinned bar's status line. Empty with no Entries.
    var heading: String? {
        guard let currentEntry else { return nil }
        guard let currentSet else { return currentEntry.noTargetHeading }
        return currentEntry.title(of: currentSet)
    }

    /// Every change is saved at once, so the Workout survives an app kill.
    private func save() {
        do {
            try workout.modelContext?.save()
        } catch {
            fatalError("Could not save the Workout: \(error)")
        }
    }
}
