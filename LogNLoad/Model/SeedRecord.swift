import Foundation
import SwiftData

extension SchemaV1 {
    /// One per seed UUID ever applied. Never deleted, so a seed the user removed is never inserted again.
    @Model final class SeedRecord {
        /// The seed's fixed UUID.
        var id: UUID = UUID()
        var version: Int = 1
        var fingerprint: String?

        init(id: UUID, fingerprint: String) {
            self.id = id
            self.fingerprint = fingerprint
        }
    }
}
