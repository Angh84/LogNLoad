import Foundation
import SwiftData

extension SchemaV1 {
    /// A tombstone for a Health delete not yet done: saved with the Workout's delete, removed once Health's succeeds.
    @Model final class PendingHealthDelete {
        var id: UUID = UUID()
        var version: Int = 1
        var workoutId: UUID?

        init(workoutId: UUID) {
            self.workoutId = workoutId
        }
    }
}
