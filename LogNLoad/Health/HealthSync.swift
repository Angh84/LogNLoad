import Foundation
import Observation
import SwiftData

/// Writes every Health-pending Workout to Health: on launch, on every return from the background, and after Finish.
@MainActor @Observable
final class HealthSync {
    private let store: HealthStore
    private var isSyncing = false
    private var isPassQueued = false

    init(store: HealthStore) {
        self.store = store
    }

    func requestAuthorization() async {
        await store.requestAuthorization()
    }

    /// One pass over the pending Workouts, silent on failure: a Workout that isn't written stays pending for the
    /// next pass. A call during a pass queues one more, so a Workout finished meanwhile is written too.
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
        for workout in Workout.healthPending(in: context) {
            guard let healthWorkout = workout.healthWorkout else { continue }
            do {
                try await store.save(healthWorkout)
            } catch {
                continue
            }
            // Deleted while the write was in flight.
            guard workout.modelContext != nil else { continue }
            workout.healthConfirmedVersion = healthWorkout.version
            do {
                try context.save()
            } catch {
                fatalError("Could not save the Workout: \(error)")
            }
        }
    }
}
