import Foundation
import SwiftData

/// One starter Exercise as it lives in source. Applied to the store on every launch (ADR-0003).
struct SeedEntry {
    let id: UUID
    var name: String
    var equipment: Equipment
    var loadType: LoadType
    var isUnilateral: Bool
    /// In stored order, which breaks weight ties.
    var muscleEmphases: [MuscleEmphasis]

    init(
        _ id: String,
        _ name: String,
        _ equipment: Equipment,
        loadType: LoadType = .loaded,
        isUnilateral: Bool = false,
        _ muscleEmphases: KeyValuePairs<MuscleGroup, Double>
    ) {
        self.id = UUID(uuidString: id)!
        self.name = name
        self.equipment = equipment
        self.loadType = loadType
        self.isUnilateral = isUnilateral
        self.muscleEmphases = muscleEmphases.map { MuscleEmphasis(muscleGroup: $0.key, weight: $0.value) }
    }

    /// Every field a source change overwrites. The format is permanent: a new one would
    /// overwrite every seed once and wipe in-app edits.
    var fingerprint: String {
        let emphases = muscleEmphases.map { "\($0.muscleGroup.rawValue):\($0.weight)" }.joined(separator: ",")
        return [name, equipment.rawValue, loadType.rawValue, "\(isUnilateral)", emphases].joined(separator: "|")
    }
}

extension SeedEntry {
    /// The launch pass of the seeding lifecycle (starter-library.md).
    static func apply(_ entries: [SeedEntry], in context: ModelContext) throws {
        var records = try context.fetch(FetchDescriptor<SeedRecord>())
        var exercises = try context.fetch(FetchDescriptor<Exercise>())
        var renames: [(exercise: Exercise, name: String)] = []
        for entry in entries {
            if let record = records.first(where: { $0.id == entry.id }) {
                guard record.fingerprint != entry.fingerprint else { continue }
                if let exercise = exercises.first(where: { $0.id == entry.id }) {
                    exercise.overwrite(with: entry)
                    renames.append((exercise, entry.name))
                }
                record.fingerprint = entry.fingerprint
                continue
            }
            if let sameName = exercises.first(where: { $0.isNamed(entry.name) }) {
                // Another seed holds the name: no Seed record, so the next launch retries.
                guard !records.contains(where: { $0.id == sameName.id }) else { continue }
                sameName.id = entry.id
                sameName.overwrite(with: entry)
                renames.append((sameName, entry.name))
            } else {
                let exercise = Exercise(
                    id: entry.id,
                    name: entry.name,
                    equipment: entry.equipment,
                    loadType: entry.loadType,
                    isUnilateral: entry.isUnilateral,
                    muscleEmphases: entry.muscleEmphases
                )
                context.insert(exercise)
                exercises.append(exercise)
            }
            let record = SeedRecord(id: entry.id, fingerprint: entry.fingerprint)
            context.insert(record)
            records.append(record)
        }
        // Renames go last and repeat while one frees a name for another, so source order doesn't matter.
        // One still colliding is skipped.
        while let index = renames.firstIndex(where: { rename in
            !exercises.contains { $0 != rename.exercise && $0.isNamed(rename.name) }
        }) {
            let rename = renames.remove(at: index)
            rename.exercise.name = rename.name
        }
        try context.save()
    }
}

private extension Exercise {
    /// Applies a changed source entry except its name, skipping what history locks (data-model.md#invariants).
    func overwrite(with entry: SeedEntry) {
        muscleEmphases = entry.muscleEmphases
        guard !hasHistory else {
            if entry.equipment.weightConvention == weightConvention { equipment = entry.equipment }
            return
        }
        equipment = entry.equipment
        loadType = entry.loadType
        isUnilateral = entry.isUnilateral
    }

    /// Exercise names are unique ignoring case, compared as stored.
    func isNamed(_ other: String) -> Bool {
        name?.caseInsensitiveCompare(other) == .orderedSame
    }
}
