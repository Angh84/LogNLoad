import Foundation
import Observation
import SwiftData

/// Keeps Health in step with the Workouts: deletes what a Pending Health delete names, and writes every Health-pending
/// Workout. It runs on launch, on every return from the background, and after Finish, an edit's Done and a delete.
@MainActor @Observable
final class HealthSync {
    /// How a rewrite after a time edit replaces the Workout's Health workout (docs/spec/healthkit.md, Edits).
    enum Rewrite {
        /// Saving the same sync identifier with a higher sync version replaces the old workout.
        case replace
        /// The fallback, should a replace leave a duplicate: delete the identifier's workouts, then save.
        case deleteThenSave
    }

    private let store: HealthStore
    private let rewrite: Rewrite
    private var isSyncing = false
    private var isPassQueued = false

    init(store: HealthStore, rewrite: Rewrite = .replace) {
        self.store = store
        self.rewrite = rewrite
    }

    func requestAuthorization() async {
        await store.requestAuthorization()
    }

    /// A launch past onboarding asks first, for an install that was never asked (docs/spec/healthkit.md, Permission).
    func syncOnLaunch(in context: ModelContext) async {
        await store.requestAuthorization()
        await sync(in: context)
    }

    /// One pass over the Pending Health deletes and the pending Workouts, silent on failure: what doesn't succeed
    /// stays pending for the next pass. A call during a pass queues one more, so a Workout finished meanwhile is
    /// written too.
    func sync(in context: ModelContext) async {
        guard !isSyncing else {
            isPassQueued = true
            return
        }
        isSyncing = true
        repeat {
            isPassQueued = false
            await pass(in: context)
        } while isPassQueued
        isSyncing = false
    }

    private func pass(in context: ModelContext) async {
        for tombstone in (try? context.fetch(FetchDescriptor<PendingHealthDelete>())) ?? [] {
            if let id = tombstone.workoutId {
                do {
                    try await store.deleteWorkouts(syncIdentifier: id)
                } catch {
                    continue
                }
            }
            context.delete(tombstone)
            save(context)
        }
        for workout in Workout.healthPending(in: context) {
            // Deleted while an earlier write was in flight.
            guard workout.modelContext != nil, let healthWorkout = workout.healthWorkout else { continue }
            do {
                if rewrite == .deleteThenSave, healthWorkout.version > 1 {
                    try await store.deleteWorkouts(syncIdentifier: healthWorkout.id)
                    guard workout.modelContext != nil else { continue }
                }
                try await store.save(healthWorkout)
            } catch {
                continue
            }
            // Deleted while the write was in flight.
            guard workout.modelContext != nil else { continue }
            workout.healthConfirmedVersion = healthWorkout.version
            save(context)
        }
    }

    private func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            fatalError("Could not save the Health sync state: \(error)")
        }
    }
}
