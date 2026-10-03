import Foundation
import HealthKit

/// Health behind one seam. The app only writes workouts, and never reads.
@MainActor
protocol HealthStore {
    /// Share permission for workouts only. The system sheet's Don't Allow is the opt-out.
    func requestAuthorization() async
    func save(_ workout: HealthWorkout) async throws
    /// Deletes the workouts this app saved with the Workout's sync identifier. Finding none counts as done.
    func deleteWorkouts(syncIdentifier id: UUID) async throws
}

/// What a finished Workout writes to Health: its times, and the sync identifier and version that let a later
/// write replace it (ADR-0002).
struct HealthWorkout: Equatable {
    let id: UUID
    let start: Date
    let end: Date
    let version: Int

    /// Exactly these three keys, nothing else (docs/spec/healthkit.md, Write on Finish).
    var metadata: [String: Any] {
        [
            HKMetadataKeySyncIdentifier: id.uuidString,
            HKMetadataKeySyncVersion: version,
            HKMetadataKeyIndoorWorkout: true,
        ]
    }
}

/// Apple Health, written through an unattached workout builder with no workout session and no samples.
@MainActor
final class AppleHealthStore: HealthStore {
    private let store = HKHealthStore()

    func requestAuthorization() async {
        // A refusal or an error both leave every write pending, which is all the app needs to know.
        try? await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
    }

    func save(_ workout: HealthWorkout) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        do {
            try await builder.beginCollection(at: workout.start)
            try await builder.addMetadata(workout.metadata)
            try await builder.endCollection(at: workout.end)
            _ = try await builder.finishWorkout()
        } catch {
            builder.discardWorkout()
            throw error
        }
    }

    func deleteWorkouts(syncIdentifier id: UUID) async throws {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: [id.uuidString])
        _ = try await store.deleteObjects(of: HKObjectType.workoutType(), predicate: predicate)
    }
}
