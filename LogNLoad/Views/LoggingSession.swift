import Foundation
import Observation
import SwiftData

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

    /// The Entry's first target Set, or its no-target state when none is left.
    func nextSet() {
        moveToFirstTargetSet()
    }

    private func moveToFirstTargetSet() {
        currentSet = currentEntry?.firstTargetSet
        isAskingRIR = false
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
