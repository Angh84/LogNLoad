import SwiftData
import SwiftUI

@main
struct LogNLoadApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try .logNLoad()
        } catch {
            fatalError("Could not open the store: \(error)")
        }
        do {
            try SeedEntry.apply(SeedEntry.starterLibrary, in: container.mainContext)
        } catch {
            fatalError("Could not apply the starter Exercise Library: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Color.black.ignoresSafeArea()
        }
        .modelContainer(container)
    }
}
