import SwiftData
import SwiftUI

@main
struct LogNLoadApp: App {
    let container: ModelContainer
    @State private var health = HealthSync(store: AppleHealthStore())

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
            RootView()
                .environment(health)
        }
        .modelContainer(container)
    }
}
