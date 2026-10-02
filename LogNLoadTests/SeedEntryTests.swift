import Foundation
import SwiftData
import Testing
@testable import LogNLoad

@MainActor
struct SeedEntryTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try .logNLoad(inMemory: true)
    }

    let lateralRaise = SeedEntry("00000000-0000-0000-0000-000000000001", "Single-Arm Cable Lateral Raise", .cable, isUnilateral: true, [.sideDelts: 1.0, .traps: 0.25])
    let assistedDip = SeedEntry("00000000-0000-0000-0000-000000000002", "Assisted Dip (Nautilus)", .machine, loadType: .assisted, [.triceps: 1.0, .lowerChest: 0.75, .frontDelts: 0.5])

    func launch(_ entries: [SeedEntry]) throws {
        try SeedEntry.apply(entries, in: context)
    }

    func exercises() throws -> [Exercise] {
        try context.fetch(FetchDescriptor<Exercise>())
    }

    func exercise(_ entry: SeedEntry) throws -> Exercise? {
        try exercises().first { $0.id == entry.id }
    }

    func record(_ entry: SeedEntry) throws -> SeedRecord? {
        try context.fetch(FetchDescriptor<SeedRecord>()).first { $0.id == entry.id }
    }

    // MARK: Fingerprint

    @Test func theFingerprintFormatNeverChanges() {
        #expect(lateralRaise.fingerprint == "Single-Arm Cable Lateral Raise|cable|loaded|true|sideDelts:1.0,traps:0.25")
    }

    // MARK: Insert

    @Test func aSeedEntryNeverAppliedIsInsertedWithItsSeedRecord() throws {
        try launch([lateralRaise, assistedDip])

        #expect(try exercises().count == 2)
        let raise = try #require(try exercise(lateralRaise))
        #expect(raise.name == "Single-Arm Cable Lateral Raise")
        #expect(raise.equipment == .cable)
        #expect(raise.loadType == .loaded)
        #expect(raise.isUnilateral)
        #expect(raise.muscleEmphases == [MuscleEmphasis(muscleGroup: .sideDelts, weight: 1), MuscleEmphasis(muscleGroup: .traps, weight: 0.25)])
        #expect(raise.note == nil)
        #expect(!raise.isArchived)
        #expect(try exercise(assistedDip)?.loadType == .assisted)
        #expect(try record(lateralRaise)?.fingerprint == lateralRaise.fingerprint)
        #expect(try record(assistedDip)?.fingerprint == assistedDip.fingerprint)
    }

    // MARK: Unchanged source

    @Test func aSeedKeepsItsInAppEditsWhileItsEntryIsUnchanged() throws {
        try launch([lateralRaise])
        let raise = try #require(try exercise(lateralRaise))
        raise.name = "Cable Lateral Raise"
        raise.muscleEmphases = [MuscleEmphasis(muscleGroup: .sideDelts, weight: 1)]
        raise.equipment = .band
        try context.save()

        try launch([lateralRaise])

        #expect(try exercises() == [raise])
        #expect(raise.name == "Cable Lateral Raise")
        #expect(raise.muscleEmphases == [MuscleEmphasis(muscleGroup: .sideDelts, weight: 1)])
        #expect(raise.equipment == .band)
        #expect(try record(lateralRaise)?.fingerprint == lateralRaise.fingerprint)
    }

    // MARK: Overwrite

    @Test func aChangedEntryOverwritesTheSeedButNotItsNoteOrArchivedFlag() throws {
        try launch([lateralRaise])
        let raise = try #require(try exercise(lateralRaise))
        raise.name = "Cable Lateral Raise"
        raise.note = "Pin 3"
        raise.isArchived = true
        try context.save()

        var changed = lateralRaise
        changed.name = "Single-Arm Cable Y Raise"
        changed.equipment = .band
        changed.loadType = .bodyweight
        changed.isUnilateral = false
        changed.muscleEmphases = [MuscleEmphasis(muscleGroup: .upperBack, weight: 1), MuscleEmphasis(muscleGroup: .sideDelts, weight: 0.5)]
        try launch([changed])

        #expect(try exercises() == [raise])
        #expect(raise.name == "Single-Arm Cable Y Raise")
        #expect(raise.equipment == .band)
        #expect(raise.loadType == .bodyweight)
        #expect(!raise.isUnilateral)
        #expect(raise.muscleEmphases == [MuscleEmphasis(muscleGroup: .upperBack, weight: 1), MuscleEmphasis(muscleGroup: .sideDelts, weight: 0.5)])
        #expect(raise.note == "Pin 3")
        #expect(raise.isArchived)
        #expect(try record(lateralRaise)?.fingerprint == changed.fingerprint)
    }

    // MARK: Overwrite with history

    /// Puts `exercise` in a finished Workout, so it has history.
    @discardableResult
    func logWorkout(with exercise: Exercise) -> Workout {
        let workout = Workout(startedAt: .now.addingTimeInterval(-3600), endedAt: .now)
        context.insert(workout)
        let entry = ExerciseEntry(workout: workout, exercise: exercise, order: 0)
        _ = WorkoutSet(entry: entry, order: 0, weight: 20, reps: 8, completedAt: workout.startedAt)
        return workout
    }

    @Test func aSeedWithHistoryKeepsItsLoadTypeSidesAndWeightConventionWhenItsEntryChanges() throws {
        try launch([assistedDip])
        let dip = try #require(try exercise(assistedDip))
        logWorkout(with: dip)
        try context.save()

        var changed = assistedDip
        changed.name = "Assisted Dip (Nautilus Nitro)"
        changed.equipment = .dumbbell
        changed.loadType = .loaded
        changed.isUnilateral = true
        changed.muscleEmphases = [MuscleEmphasis(muscleGroup: .triceps, weight: 1)]
        try launch([changed])

        #expect(dip.name == "Assisted Dip (Nautilus Nitro)")
        #expect(dip.muscleEmphases == [MuscleEmphasis(muscleGroup: .triceps, weight: 1)])
        #expect(dip.equipment == .machine)
        #expect(dip.loadType == .assisted)
        #expect(!dip.isUnilateral)
        #expect(try record(assistedDip)?.fingerprint == changed.fingerprint)
    }

    @Test func aSeedWithHistoryTakesNewEquipmentWeighedTheSameWay() throws {
        try launch([assistedDip])
        logWorkout(with: try #require(try exercise(assistedDip)))
        try context.save()

        var changed = assistedDip
        changed.equipment = .cable
        try launch([changed])

        #expect(try exercise(assistedDip)?.equipment == .cable)
    }

    @Test func aSkippedPartIsNotRetriedUntilTheSourceChangesAgain() throws {
        try launch([assistedDip])
        let workout = logWorkout(with: try #require(try exercise(assistedDip)))
        try context.save()
        var changed = assistedDip
        changed.loadType = .loaded
        try launch([changed])

        context.delete(workout)
        try context.save()
        #expect(try exercise(assistedDip)?.hasHistory == false)
        try launch([changed])

        #expect(try exercise(assistedDip)?.loadType == .assisted)
    }

    // MARK: Renames

    @discardableResult
    func customExercise(_ name: String, isArchived: Bool = false) -> Exercise {
        let exercise = Exercise(name: name, equipment: .cable, isArchived: isArchived, muscleEmphases: [MuscleEmphasis(muscleGroup: .upperBack, weight: 1)])
        context.insert(exercise)
        return exercise
    }

    @Test func aRenameOntoAnArchivedExercisesNameIsSkipped() throws {
        try launch([lateralRaise])
        customExercise("Cable Y Raise", isArchived: true)
        try context.save()

        var changed = lateralRaise
        changed.name = "cable y raise"
        changed.muscleEmphases = [MuscleEmphasis(muscleGroup: .sideDelts, weight: 0.9)]
        try launch([changed])

        let raise = try #require(try exercise(lateralRaise))
        #expect(raise.name == "Single-Arm Cable Lateral Raise")
        #expect(raise.muscleEmphases == [MuscleEmphasis(muscleGroup: .sideDelts, weight: 0.9)])
        #expect(try record(lateralRaise)?.fingerprint == changed.fingerprint)
    }

    @Test func aRenameThatOnlyChangesCaseIsApplied() throws {
        try launch([lateralRaise])

        var changed = lateralRaise
        changed.name = "Single-arm Cable Lateral Raise"
        try launch([changed])

        #expect(try exercise(lateralRaise)?.name == "Single-arm Cable Lateral Raise")
    }

    @Test func aChangedEntryPutsBackANameRenamedInTheApp() throws {
        try launch([lateralRaise])
        let raise = try #require(try exercise(lateralRaise))
        raise.name = "Cable Lateral Raise"
        try context.save()

        var changed = lateralRaise
        changed.muscleEmphases = [MuscleEmphasis(muscleGroup: .sideDelts, weight: 0.9)]
        try launch([changed])

        #expect(raise.name == "Single-Arm Cable Lateral Raise")
    }

    @Test func aRenameOntoANameAnotherSeedGivesUpInTheSameLaunchIsApplied() throws {
        try launch([assistedDip, lateralRaise])

        var renamedDip = assistedDip
        renamedDip.name = "Single-Arm Cable Lateral Raise"
        var renamedRaise = lateralRaise
        renamedRaise.name = "Cable Lateral Raise"
        try launch([renamedDip, renamedRaise])

        #expect(try exercise(assistedDip)?.name == "Single-Arm Cable Lateral Raise")
        #expect(try exercise(lateralRaise)?.name == "Cable Lateral Raise")
    }

    @Test func twoSeedsSwappingNamesKeepTheirNames() throws {
        try launch([assistedDip, lateralRaise])

        var renamedDip = assistedDip
        renamedDip.name = lateralRaise.name
        var renamedRaise = lateralRaise
        renamedRaise.name = assistedDip.name
        try launch([renamedDip, renamedRaise])

        #expect(try exercise(assistedDip)?.name == "Assisted Dip (Nautilus)")
        #expect(try exercise(lateralRaise)?.name == "Single-Arm Cable Lateral Raise")
        #expect(try record(assistedDip)?.fingerprint == renamedDip.fingerprint)
    }

    // MARK: Adopt

    @Test func aNewSeedEntryAdoptsTheCustomExerciseWithItsName() throws {
        let custom = customExercise("single-arm cable lateral raise")
        custom.note = "Handle low"
        try context.save()

        try launch([lateralRaise])

        #expect(try exercises() == [custom])
        #expect(custom.id == lateralRaise.id)
        #expect(custom.name == "Single-Arm Cable Lateral Raise")
        #expect(custom.isUnilateral)
        #expect(custom.muscleEmphases == lateralRaise.muscleEmphases)
        #expect(custom.note == "Handle low")
        #expect(!custom.isArchived)
        #expect(try record(lateralRaise)?.fingerprint == lateralRaise.fingerprint)
    }

    @Test func anAdoptedArchivedExerciseKeepsItsHistoryAndArchivedFlag() throws {
        let custom = customExercise("Single-Arm Cable Lateral Raise", isArchived: true)
        let workout = logWorkout(with: custom)
        try context.save()

        try launch([lateralRaise])

        #expect(try exercises() == [custom])
        #expect(custom.id == lateralRaise.id)
        #expect(workout.sortedEntries.map(\.exercise) == [custom])
        #expect(custom.isArchived)
        #expect(!custom.isUnilateral)
        #expect(custom.muscleEmphases == lateralRaise.muscleEmphases)
        #expect(try record(lateralRaise)?.fingerprint == lateralRaise.fingerprint)
    }

    // MARK: Skip

    @Test func aNewSeedEntryWaitsUntilAnotherSeedFreesItsName() throws {
        let twin = SeedEntry("00000000-0000-0000-0000-000000000003", "single-arm cable lateral raise", .cable, [.sideDelts: 1.0])
        try launch([lateralRaise, twin])

        #expect(try exercises().map(\.id) == [lateralRaise.id])
        #expect(try record(twin) == nil)

        try #require(try exercise(lateralRaise)).name = "Cable Lateral Raise"
        try context.save()
        try launch([lateralRaise, twin])

        #expect(try exercise(lateralRaise)?.name == "Cable Lateral Raise")
        #expect(try exercise(twin)?.name == "single-arm cable lateral raise")
        #expect(try record(twin)?.fingerprint == twin.fingerprint)
    }

    // MARK: Deleted and removed seeds

    @Test func aDeletedSeedNeverComesBackEvenWhenItsEntryChanges() throws {
        try launch([lateralRaise])
        context.delete(try #require(try exercise(lateralRaise)))
        try context.save()

        try launch([lateralRaise])
        var changed = lateralRaise
        changed.muscleEmphases = [MuscleEmphasis(muscleGroup: .sideDelts, weight: 0.9)]
        try launch([changed])

        #expect(try exercises().isEmpty)
        #expect(try record(lateralRaise)?.fingerprint == changed.fingerprint)
    }

    @Test func aSeedRemovedFromSourceLeavesTheStoreUntouched() throws {
        try launch([lateralRaise, assistedDip])

        try launch([assistedDip])

        let raise = try #require(try exercise(lateralRaise))
        #expect(raise.name == "Single-Arm Cable Lateral Raise")
        #expect(raise.muscleEmphases == lateralRaise.muscleEmphases)
        #expect(try record(lateralRaise)?.fingerprint == lateralRaise.fingerprint)
    }
}
