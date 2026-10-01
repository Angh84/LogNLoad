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
    }

    var body: some Scene {
        WindowGroup {
            Color.black.ignoresSafeArea()
        }
        .modelContainer(container)
    }
}
