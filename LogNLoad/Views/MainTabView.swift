import SwiftData
import SwiftUI

struct MainTabView: View {
    enum AppTab { case muscles, history, exercises }

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(HealthSync.self) private var health
    @Query(filter: #Predicate<Workout> { $0.endedAt == nil }) private var activeWorkouts: [Workout]
    /// Kept while the cover is minimized, so expanding it keeps the current Entry and Set.
    @State private var session: LoggingSession?
    @State private var isLoggingExpanded = false
    @State private var tab = AppTab.muscles
    @State private var finishes = 0
    /// The Workout just finished, for the History list to land on.
    @State private var justFinished: UUID?
    @Namespace private var cover

    var body: some View {
        TabView(selection: $tab) {
            Tab("Muscles", systemImage: "figure.strengthtraining.traditional", value: .muscles) {
                MusclesView()
            }
            Tab("History", systemImage: "clock", value: .history) {
                HistoryView(justFinished: justFinished)
            }
            Tab("Exercises", systemImage: "dumbbell", value: .exercises) {
                LibraryView()
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
                LoggingView(session: session, onFinish: finished, onDiscard: closeCover)
                    .navigationTransition(.zoom(sourceID: "logging", in: cover))
            }
        }
        // A merge in the Library can combine the current Entry away.
        .environment(session)
        .sensoryFeedback(.success, trigger: finishes)
        .onAppear(perform: openActiveWorkout)
        .onChange(of: scenePhase) { oldPhase, _ in
            if oldPhase == .background { askIfStale() }
        }
    }

    /// A launch with an Active Workout opens the cover expanded.
    private func openActiveWorkout() {
        guard session == nil, let workout = activeWorkouts.first else { return }
        session = LoggingSession(workout: workout)
        isLoggingExpanded = true
        askIfStale()
    }

    /// On launch and on return from the background, a stale Workout expands the cover with the prompt on top,
    /// its "N ago" counted from now also when it was already up.
    private func askIfStale() {
        let now = Date.now
        guard let session, session.isStale(at: now) else { return }
        session.stalePromptAt = now
        isLoggingExpanded = true
    }

    /// After Finish the cover closes onto History, the bar returns to "Start Workout", and the Workout is
    /// written to Health.
    private func finished() {
        finishes += 1
        justFinished = session?.workout.id
        tab = .history
        closeCover()
        Task { await health.sync(in: context) }
    }

    /// The session goes at once, so nothing renders the finished or deleted Workout's records.
    private func closeCover() {
        isLoggingExpanded = false
        session = nil
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
