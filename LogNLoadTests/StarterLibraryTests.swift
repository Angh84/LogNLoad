import Foundation
import SwiftData
import Testing
@testable import LogNLoad

@MainActor
struct StarterLibraryTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let entries = SeedEntry.starterLibrary

    init() throws {
        container = try .logNLoad(inMemory: true)
    }

    func entry(_ name: String) throws -> SeedEntry {
        try #require(entries.first { $0.name == name })
    }

    // MARK: Source

    @Test func thereAre74EntriesWithUniqueUUIDsAndNames() {
        #expect(entries.count == 74)
        #expect(Set(entries.map(\.id)).count == 74)
        for (index, entry) in entries.enumerated() {
            #expect(!entries[..<index].contains { $0.name.caseInsensitiveCompare(entry.name) == .orderedSame }, "\(entry.name)")
        }
    }

    @Test func everyEntryHasValidMuscleEmphasesAndATrimmedName() {
        for entry in entries {
            #expect(!entry.muscleEmphases.isEmpty, "\(entry.name)")
            #expect(Set(entry.muscleEmphases.map(\.muscleGroup)).count == entry.muscleEmphases.count, "\(entry.name)")
            #expect(entry.muscleEmphases.allSatisfy { (0...1).contains($0.weight) }, "\(entry.name)")
            #expect(trimmed(entry.name) == entry.name, "\(entry.name)")
        }
    }

    @Test func entriesCarryTheirEquipmentLoadTypeSidesAndEmphasesInOrder() throws {
        let deadlift = try entry("Deadlift")
        #expect(deadlift.equipment == .barbell)
        #expect(deadlift.loadType == .loaded)
        #expect(!deadlift.isUnilateral)
        #expect(deadlift.muscleEmphases == [
            MuscleEmphasis(muscleGroup: .glutes, weight: 0.75),
            MuscleEmphasis(muscleGroup: .hamstrings, weight: 0.75),
            MuscleEmphasis(muscleGroup: .lowerBack, weight: 0.75),
            MuscleEmphasis(muscleGroup: .quads, weight: 0.5),
            MuscleEmphasis(muscleGroup: .traps, weight: 0.5),
            MuscleEmphasis(muscleGroup: .adductors, weight: 0.25),
        ])

        let lunge = try entry("Bodyweight Lunge")
        #expect(lunge.equipment == .bodyweight)
        #expect(lunge.loadType == .bodyweight)
        #expect(lunge.isUnilateral)

        #expect(try entry("Assisted Pull-Up (Nautilus)").loadType == .assisted)
        #expect(try entry("Hammer Curl").muscleEmphases.map(\.weight) == [0.9, 0.5, 0.5])
    }

    // MARK: Launch

    /// Every stored field the seeding lifecycle reads or writes.
    struct Snapshot: Equatable {
        let exercises: [String]
        let records: [String]

        init(_ context: ModelContext) throws {
            exercises = try context.fetch(FetchDescriptor<Exercise>())
                .map { "\($0.id)|\($0.name ?? "")|\(String(describing: $0.equipment))|\($0.loadType)|\($0.isUnilateral)|\($0.muscleEmphases)|\($0.note ?? "")|\($0.isArchived)" }
                .sorted()
            records = try context.fetch(FetchDescriptor<SeedRecord>())
                .map { "\($0.id)|\($0.fingerprint ?? "")" }
                .sorted()
        }
    }

    @Test func aFreshInstallHasEveryStarterExerciseAfterTheFirstLaunch() throws {
        try SeedEntry.apply(entries, in: context)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        #expect(exercises.count == 74)
        #expect(Set(exercises.map(\.id)) == Set(entries.map(\.id)))
        #expect(exercises.allSatisfy { $0.note == nil && !$0.isArchived })
        #expect(try context.fetchCount(FetchDescriptor<SeedRecord>()) == 74)
    }

    @Test func aSecondLaunchChangesNothing() throws {
        try SeedEntry.apply(entries, in: context)
        let afterFirst = try Snapshot(context)
        #expect(afterFirst.exercises.count == 74)

        let relaunched = ModelContext(container)
        try SeedEntry.apply(entries, in: relaunched)

        #expect(try Snapshot(relaunched) == afterFirst)
    }
}
