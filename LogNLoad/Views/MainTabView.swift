import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("History", systemImage: "clock") {
                NavigationStack {
                    Color.clear.navigationTitle("History")
                }
            }
            Tab("Exercises", systemImage: "dumbbell") {
                NavigationStack {
                    Color.clear.navigationTitle("Exercises")
                }
            }
        }
        .tabViewBottomAccessory {
            // Starting the Workout comes with logging (#30).
            Button("Start Workout", systemImage: "plus") {}
        }
    }
}
