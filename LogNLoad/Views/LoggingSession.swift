import Foundation
import Observation
import SwiftData
import SwiftUI

/// The logging screen's state, for the Active Workout or an edit session on a finished one. The current Entry and
/// Set live only here, never in the store, so a relaunch reopens on the first target Set.
@MainActor @Observable
final class LoggingSession {
    let workout: Workout
    /// An edit session on a finished Workout: its changes wait for Done.
    let isEditing: Bool
    private(set) var currentEntry: ExerciseEntry?
    /// Empty when the current Entry has no target Set left.
    private(set) var currentSet: WorkoutSet?
    /// The "Reps in reserve?" panel for the Working Set just completed.
    private(set) var isAskingRIR = false
    /// Up right after "Start Workout", and from the "+" chip and "Add Exercise".
    var isPickerPresented = false
    /// A short message over the logging screen, which clears it after a moment.
    var toast: String?
    /// The last Resume tap on the stale prompt. Kept in memory only, so a relaunch soon after Resume asks again.
    private var resumedAt: Date?
    /// When the stale prompt came up, while it is up.
    var stalePromptAt: Date?

    init(workout: Workout, isEditing: Bool = false) {
        self.workout = workout
        self.isEditing = isEditing
        let entries = workout.sortedEntries
        if isEditing {
            currentEntry = entries.first
            currentSet = currentEntry?.sortedSets.first
        } else {
            currentEntry = entries.first { $0.firstTargetSet != nil } ?? entries.last
            currentSet = currentEntry?.firstTargetSet
        }
    }

    /// An edit session on a finished Workout, in its own `ModelContext` so that Cancel's rollback can't touch the
    /// Active Workout.
    static func editing(_ workout: Workout) -> LoggingSession? {
        guard let container = workout.modelContext?.container else { return nil }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let id = workout.id
        guard let copy = try? context.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.id == id })).first else { return nil }
        return LoggingSession(workout: copy, isEditing: true)
    }

    /// Appends the Exercise's Entry, or goes to it with a toast when it is already in the Workout.
    func add(_ exercise: Exercise) {
        // The picker's Exercises live in the main context; an edit session works in its own.
        let exercise = workout.modelContext?.model(for: exercise.persistentModelID) as? Exercise ?? exercise
        if workout.contains(exercise) {
            toast = "\(exercise.name ?? "") is already in this Workout"
        }
        let entry = workout.add(exercise)
        save()
        select(entry)
    }

    /// Saving the Exercise form from the picker's Create row: stores the new Exercise and adds it.
    func create(_ exercise: Exercise) {
        workout.modelContext?.insert(exercise)
        add(exercise)
    }

    /// Makes the Entry current, on its first target Set, or on its first Set while editing.
    func select(_ entry: ExerciseEntry) {
        currentEntry = entry
        currentSet = isEditing ? entry.sortedSets.first : entry.firstTargetSet
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

    /// Deletes a Set of the current Entry. When it was current, the Entry's first target Set becomes current; while
    /// editing, the following Set, else the previous one, else "No Sets".
    func delete(_ set: WorkoutSet) {
        let wasCurrent = set == currentSet
        let neighbour = Self.neighbour(of: set, in: currentEntry?.sortedSets ?? [])
        workout.modelContext?.delete(set)
        save()
        guard wasCurrent else { return }
        if isEditing {
            currentSet = neighbour
        } else {
            moveToFirstTargetSet()
        }
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
        guard workout.sortedEntries.contains(entry) else { return }
        let neighbour = Self.neighbour(of: entry, in: workout.sortedEntries)
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

    /// The Entry's first target Set, or its no-target state when none is left. While editing, the following Set.
    func nextSet() {
        if isEditing {
            currentSet = followingSet
        } else {
            moveToFirstTargetSet()
        }
    }

    /// The Set after the current one, for edit mode's "Next Set". Empty on the Entry's last Set.
    var followingSet: WorkoutSet? {
        let sets = currentEntry?.sortedSets ?? []
        guard let currentSet, let index = sets.firstIndex(of: currentSet), index + 1 < sets.count else { return nil }
        return sets[index + 1]
    }

    /// What stops Done, in the spec's order.
    enum DoneProblem: Equatable {
        case endNotAfterStart, endInFuture, overlaps(Workout), noSets

        var overlapping: Workout? {
            if case .overlaps(let workout) = self { workout } else { nil }
        }
    }

    /// The first rule the edited Workout breaks: its end after its start and not in the future, no overlap with
    /// another Workout (the Active one ends now), and at least one Set left.
    func doneProblem(now: Date) -> DoneProblem? {
        guard let start = workout.startedAt, let end = workout.endedAt else { return nil }
        if end <= start { return .endNotAfterStart }
        if end > now { return .endInFuture }
        var descriptor = FetchDescriptor<Workout>()
        descriptor.sortBy = [SortDescriptor(\.startedAt)]
        let others = ((try? workout.modelContext?.fetch(descriptor)) ?? []).filter { $0.id != workout.id }
        if let other = others.first(where: { workout.overlaps($0, now: now) }) { return .overlaps(other) }
        if workout.sortedEntries.allSatisfy({ $0.sortedSets.isEmpty }) { return .noSets }
        return nil
    }

    /// Done: drops every Entry left without Sets, then saves the whole edit at once.
    func saveEdit() {
        guard let context = workout.modelContext else { return }
        for entry in workout.sortedEntries where entry.sortedSets.isEmpty {
            context.delete(entry)
        }
        do {
            try context.save()
        } catch {
            fatalError("Could not save the edited Workout: \(error)")
        }
        // The main context keeps its own copies, and refetching is what brings their stored values up to date.
        let main = context.container.mainContext
        let id = workout.id
        _ = try? main.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.id == id }))
        _ = try? main.fetch(FetchDescriptor<ExerciseEntry>(predicate: #Predicate { $0.workout?.id == id }))
        _ = try? main.fetch(FetchDescriptor<WorkoutSet>(predicate: #Predicate { $0.entry?.workout?.id == id }))
        // Exercises gained or lost an Entry, which their Last Performance and Prefill read.
        _ = try? main.fetch(FetchDescriptor<Exercise>())
    }

    /// Cancel: discards every change of the edit session.
    func cancelEdit() {
        workout.modelContext?.rollback()
    }

    /// Whether Cancel has changes to discard.
    var hasEdits: Bool {
        workout.modelContext?.hasChanges ?? false
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

    /// What takes over when `item` goes: the item after it, else the one before, else none.
    private static func neighbour<Item: Equatable>(of item: Item, in items: [Item]) -> Item? {
        guard let index = items.firstIndex(of: item) else { return nil }
        return index + 1 < items.count ? items[index + 1] : index > 0 ? items[index - 1] : nil
    }

    /// Every change is saved at once, so the Workout survives an app kill. While editing, changes wait for Done, and
    /// only the context's relationships are brought up to date.
    private func save() {
        guard !isEditing else {
            workout.modelContext?.processPendingChanges()
            return
        }
        do {
            try workout.modelContext?.save()
        } catch {
            fatalError("Could not save the Workout: \(error)")
        }
    }
}

extension LoggingSession: Identifiable {}
