import SwiftData
import SwiftUI

struct MainTabView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Workout> { $0.endedAt == nil }) private var activeWorkouts: [Workout]
    /// Kept while the cover is minimized, so expanding it keeps the current Entry and Set.
    @State private var session: LoggingSession?
    @State private var isLoggingExpanded = false
    @Namespace private var cover

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
            if let session {
                Button { isLoggingExpanded = true } label: {
                    WorkoutBar(session: session)
                }
                .buttonStyle(.plain)
                .matchedTransitionSource(id: "logging", in: cover)
            } else {
                Button("Start Workout", systemImage: "plus", action: startWorkout)
            }
        }
        .fullScreenCover(isPresented: $isLoggingExpanded) {
            if let session {
                LoggingView(session: session)
                    .navigationTransition(.zoom(sourceID: "logging", in: cover))
            }
        }
        .onAppear(perform: openActiveWorkout)
    }

    /// A launch with an Active Workout opens the cover expanded.
    private func openActiveWorkout() {
        guard session == nil, let workout = activeWorkouts.first else { return }
        session = LoggingSession(workout: workout)
        isLoggingExpanded = true
    }

    private func startWorkout() {
        do {
            let session = LoggingSession(workout: try Workout.start(at: .now, in: context))
            session.isPickerPresented = true
            self.session = session
            isLoggingExpanded = true
        } catch {
            fatalError("Could not start the Workout: \(error)")
        }
    }
}

/// The pinned bar during the Active Workout: the current Exercise, the card's heading and the elapsed timer.
private struct WorkoutBar: View {
    let session: LoggingSession

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                if let entry = session.currentEntry {
                    Text(entry.exercise?.name ?? "")
                        .font(.subheadline.weight(.semibold))
                    Text(session.heading ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No Exercises yet")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .lineLimit(1)
            Spacer()
            ElapsedTimer(workout: session.workout)
                .font(.subheadline.monospacedDigit())
        }
        .padding(.horizontal)
        .contentShape(.rect)
    }
}
