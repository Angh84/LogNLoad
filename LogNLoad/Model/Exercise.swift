import Foundation
import SwiftData

extension SchemaV1 {
    @Model final class Exercise {
        /// A seed's fixed UUID. Changes only when a custom Exercise is adopted as a seed.
        var id: UUID = UUID()
        var version: Int = 1
        var name: String?
        var equipment: Equipment?
        var loadType: LoadType = LoadType.loaded
        var isUnilateral: Bool = false
        var note: String?
        var isArchived: Bool = false
        /// In stored order, which breaks weight ties (ADR-0004).
        @Attribute(.codable) var muscleEmphases: [MuscleEmphasis] = []
        @Relationship(deleteRule: .nullify, inverse: \ExerciseEntry.exercise)
        var entries: [ExerciseEntry]? = []

        init(
            id: UUID = UUID(),
            name: String,
            equipment: Equipment,
            loadType: LoadType = .loaded,
            isUnilateral: Bool = false,
            note: String? = nil,
            isArchived: Bool = false,
            muscleEmphases: [MuscleEmphasis]
        ) {
            self.id = id
            self.name = trimmed(name)
            self.equipment = equipment
            self.loadType = loadType
            self.isUnilateral = isUnilateral
            self.note = trimmed(note)
            self.isArchived = isArchived
            self.muscleEmphases = muscleEmphases
        }
    }
}

extension Exercise {
    var weightConvention: WeightConvention? { equipment?.weightConvention }

    /// The Exercise that holds `name` under the uniqueness rule: ignoring case, Archived Exercises included,
    /// compared trimmed, as names are stored.
    static func named(_ name: String, in context: ModelContext) -> Exercise? {
        guard let name = trimmed(name) else { return nil }
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        return exercises.first { $0.name?.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Whether this Exercise can replace `other` in a swap or merge.
    func isCompatible(with other: Exercise) -> Bool {
        self != other
            && !isArchived
            && loadType == other.loadType
            && isUnilateral == other.isUnilateral
            && weightConvention == other.weightConvention
    }

    /// The picker's "Recent": up to 8 Exercises from finished Workouts, newest `startedAt` first, each once, a
    /// Workout's Exercises in its Entry order. `workout`'s own, Archived Exercises and those `isOffered` turns away
    /// (the swap picker's) are left out before counting.
    static func recent(for workout: Workout, in context: ModelContext, where isOffered: (Exercise) -> Bool = { _ in true }) -> [Exercise] {
        var descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.endedAt != nil })
        descriptor.sortBy = [SortDescriptor(\.startedAt, order: .reverse)]
        let finished = (try? context.fetch(descriptor)) ?? []
        var recent: [Exercise] = []
        for exercise in finished.lazy.flatMap(\.exercises) {
            guard !exercise.isArchived, !workout.contains(exercise), !recent.contains(exercise), isOffered(exercise) else { continue }
            recent.append(exercise)
            if recent.count == 8 { break }
        }
        return recent
    }

    /// With history, equipment changes only within its weight convention; without, to any of the eight.
    var allowedEquipment: [Equipment] {
        guard hasHistory, let weightConvention else { return Equipment.allCases }
        return Equipment.allCases.filter { $0.weightConvention == weightConvention }
    }

    /// The Library list: non-archived Exercises under their Body Area placement, in Body Area order, A-Z, with
    /// empty Body Areas left out.
    static func librarySections(_ exercises: [Exercise]) -> [(area: BodyArea, exercises: [Exercise])] {
        let listed = exercises.filter { !$0.isArchived }
        return BodyArea.allCases.compactMap { area in
            let inArea = listed
                .filter { $0.bodyArea == area }
                .sorted { ($0.name ?? "").localizedStandardCompare($1.name ?? "") == .orderedAscending }
            return inArea.isEmpty ? nil : (area, inArea)
        }
    }

    /// Entries in any Workout, the Active Workout included.
    var hasHistory: Bool { !(entries ?? []).isEmpty }

    var workoutCount: Int {
        Set((entries ?? []).compactMap { $0.workout?.id }).count
    }

    /// Its Entries in finished Workouts, newest `startedAt` first: the Exercise page's history.
    var finishedHistory: [ExerciseEntry] {
        (entries ?? [])
            .filter { $0.workout?.isActive == false }
            .sorted { ($0.workout?.startedAt ?? .distantPast) > ($1.workout?.startedAt ?? .distantPast) }
    }

    /// The Sets from the finished Workout with the latest start that contains this Exercise.
    var lastPerformance: [WorkoutSet]? {
        (entries ?? [])
            .filter { $0.workout?.isActive == false }
            .max { ($0.workout?.startedAt ?? .distantPast) < ($1.workout?.startedAt ?? .distantPast) }?
            .sortedSets
    }

    /// Saving the edit form. With history, Load Type and Unilateral stay as they are and equipment changes only
    /// within its weight convention, whatever the form held when the Exercise gained its history.
    func update(name: String, equipment: Equipment, loadType: LoadType, isUnilateral: Bool, note: String, muscleEmphases: [MuscleEmphasis]) {
        self.name = trimmed(name)
        if allowedEquipment.contains(equipment) { self.equipment = equipment }
        if !hasHistory {
            self.loadType = loadType
            self.isUnilateral = isUnilateral
        }
        self.note = trimmed(note)
        self.muscleEmphases = muscleEmphases
    }

    /// Highest weight first, ties in stored order.
    var emphasesInDisplayOrder: [MuscleEmphasis] {
        muscleEmphases.enumerated()
            .sorted { $0.element.weight != $1.element.weight ? $0.element.weight > $1.element.weight : $0.offset < $1.offset }
            .map(\.element)
    }

    var topMuscleGroup: MuscleGroup? { emphasesInDisplayOrder.first?.muscleGroup }

    /// Where the Library lists this Exercise.
    var bodyArea: BodyArea? { topMuscleGroup?.bodyArea }
}
