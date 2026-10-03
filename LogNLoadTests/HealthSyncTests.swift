import Foundation
import HealthKit
import SwiftData
import Testing
@testable import LogNLoad

/// Records permission requests, saves and deletes, and fails every save while `isFailingSaves` and every delete while
/// `isFailingDeletes`.
@MainActor
final class FakeHealthStore: HealthStore {
    var saved: [HealthWorkout] = []
    var deleted: [UUID] = []
    var isFailingSaves = false
    var isFailingDeletes = false
    /// "request", "save" and "delete", in the order they happen.
    var calls: [String] = []

    func requestAuthorization() async {
        calls.append("request")
    }

    func save(_ workout: HealthWorkout) async throws {
        if isFailingSaves { throw CocoaError(.userCancelled) }
        saved.append(workout)
        calls.append("save")
    }

    func deleteWorkouts(syncIdentifier id: UUID) async throws {
        if isFailingDeletes { throw CocoaError(.userCancelled) }
        deleted.append(id)
        calls.append("delete")
    }
}

@MainActor
struct HealthSyncTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let store = FakeHealthStore()
    let sync: HealthSync

    init() throws {
        container = try .logNLoad(inMemory: true)
        sync = HealthSync(store: store)
    }

    func day(_ day: Int, _ hour: Int = 17) -> Date {
        DateComponents(calendar: .current, year: 2026, month: 9, day: day, hour: hour).date!
    }

    @discardableResult
    func workout(_ day: Int, finished: Bool = true) -> Workout {
        let workout = Workout(startedAt: self.day(day), endedAt: finished ? self.day(day, 18) : nil)
        context.insert(workout)
        return workout
    }

    @Test func aHealthWorkoutCarriesOnlyItsSyncIdentifierSyncVersionAndIndoor() throws {
        let id = UUID()
        let workout = HealthWorkout(id: id, start: .now, end: .now, version: 3)

        let metadata = workout.metadata

        #expect(metadata.count == 3)
        #expect(metadata[HKMetadataKeySyncIdentifier] as? String == id.uuidString)
        #expect(metadata[HKMetadataKeySyncVersion] as? Int == 3)
        #expect(metadata[HKMetadataKeyIndoorWorkout] as? Bool == true)
    }

    @Test func aPassWritesEachPendingWorkoutWithItsStoredTimesAndConfirmsTheVersion() async throws {
        let finished = workout(28)
        finished.healthWriteCounter = 2
        try context.save()

        await sync.sync(in: context)

        #expect(store.saved == [HealthWorkout(id: finished.id, start: day(28), end: day(28, 18), version: 2)])
        #expect(finished.healthConfirmedVersion == 2)
        #expect(!finished.isHealthPending)
        let fresh = ModelContext(container)
        #expect(try fresh.fetch(FetchDescriptor<Workout>()).first?.healthConfirmedVersion == 2)
    }

    @Test func theActiveWorkoutAndConfirmedWorkoutsAreNotWritten() async throws {
        workout(30, finished: false)
        let confirmed = workout(28)
        confirmed.healthConfirmedVersion = 1
        try context.save()

        await sync.sync(in: context)

        #expect(store.saved.isEmpty)
    }

    @Test func aFailedWriteStaysPendingAndTheNextPassWritesIt() async throws {
        let finished = workout(28)
        try context.save()
        store.isFailingSaves = true

        await sync.sync(in: context)
        #expect(finished.isHealthPending)
        #expect(finished.healthConfirmedVersion == nil)

        store.isFailingSaves = false
        await sync.sync(in: context)
        #expect(store.saved.map(\.id) == [finished.id])
        #expect(!finished.isHealthPending)
    }

    @Test func aWorkoutFinishedDuringAPassIsWrittenByTheQueuedPass() async throws {
        workout(27)
        try context.save()
        let blocking = BlockingHealthStore()
        let blockingSync = HealthSync(store: blocking)

        let mainContext = context
        let first = Task { await blockingSync.sync(in: mainContext) }
        await blocking.started()
        let late = workout(28)
        try context.save()
        await blockingSync.sync(in: context)
        blocking.release()
        await first.value

        #expect(blocking.saved.count == 2)
        #expect(!late.isHealthPending)
    }

    @Test func aWorkoutDeletedDuringAPassIsNotWritten() async throws {
        workout(27)
        let deleted = workout(28)
        try context.save()
        let blocking = BlockingHealthStore()
        let blockingSync = HealthSync(store: blocking)

        let mainContext = context
        let pass = Task { await blockingSync.sync(in: mainContext) }
        await blocking.started()
        try deleted.delete()
        blocking.release()
        await pass.value

        #expect(blocking.saved.count == 1)
    }

    // MARK: Rewrites and deletes

    @Test func aRewriteSavesTheHigherSyncVersionToReplaceTheOldWorkout() async throws {
        let edited = workout(28)
        edited.healthWriteCounter = 2
        edited.healthConfirmedVersion = 1
        try context.save()

        await sync.sync(in: context)

        #expect(store.calls == ["save"])
        #expect(store.saved.map(\.version) == [2])
        #expect(!edited.isHealthPending)
    }

    @Test func theFallbackRewriteDeletesTheSyncIdentifiersWorkoutsThenSaves() async throws {
        let first = workout(27)
        let edited = workout(28)
        edited.healthWriteCounter = 2
        edited.healthConfirmedVersion = 1
        try context.save()
        let fallback = HealthSync(store: store, rewrite: .deleteThenSave)

        await fallback.sync(in: context)

        #expect(store.calls == ["save", "delete", "save"])
        #expect(store.deleted == [edited.id])
        #expect(store.saved.map(\.id) == [first.id, edited.id])
    }

    @Test func deletingAWorkoutDeletesItsHealthWorkoutsAndThenItsPendingHealthDelete() async throws {
        let gone = workout(28)
        let id = gone.id
        try context.save()
        try gone.delete()
        #expect(try context.fetch(FetchDescriptor<PendingHealthDelete>()).map(\.workoutId) == [id])

        await sync.sync(in: context)

        #expect(store.deleted == [id])
        #expect(try context.fetchCount(FetchDescriptor<PendingHealthDelete>()) == 0)
    }

    @Test func aFailedHealthDeleteStaysPendingUntilARetrySucceeds() async throws {
        let gone = workout(28)
        try context.save()
        try gone.delete()
        store.isFailingDeletes = true

        await sync.sync(in: context)
        #expect(try context.fetchCount(FetchDescriptor<PendingHealthDelete>()) == 1)

        store.isFailingDeletes = false
        await sync.sync(in: context)
        #expect(try context.fetchCount(FetchDescriptor<PendingHealthDelete>()) == 0)
    }

    @Test func aLaunchPastOnboardingRequestsPermissionBeforeItsPass() async throws {
        workout(28)
        try context.save()

        await sync.syncOnLaunch(in: context)

        #expect(store.calls == ["request", "save"])
    }
}

/// Holds the first save until `release()`, to finish a Workout while a pass is in flight.
@MainActor
final class BlockingHealthStore: HealthStore {
    var saved: [HealthWorkout] = []
    private var held: CheckedContinuation<Void, Never>?
    private var waiting: CheckedContinuation<Void, Never>?

    func requestAuthorization() async {}

    func deleteWorkouts(syncIdentifier id: UUID) async throws {}

    func save(_ workout: HealthWorkout) async throws {
        saved.append(workout)
        guard saved.count == 1 else { return }
        waiting?.resume()
        waiting = nil
        await withCheckedContinuation { held = $0 }
    }

    /// Returns once the first save is in flight.
    func started() async {
        guard saved.isEmpty else { return }
        await withCheckedContinuation { waiting = $0 }
    }

    func release() {
        held?.resume()
        held = nil
    }
}
