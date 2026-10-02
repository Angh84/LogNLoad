import SwiftData
import SwiftUI

/// The History tab's root: every finished Workout, newest first, in week sections.
struct HistoryView: View {
    /// The Workout just finished, which the list lands on and highlights briefly.
    let justFinished: UUID?
    @State private var path: [Workout] = []
    @State private var workoutToDelete: Workout?
    @State private var toast: String?

    var body: some View {
        NavigationStack(path: $path) {
            HistoryList(justFinished: justFinished, workoutToDelete: $workoutToDelete)
                .navigationTitle("History")
                .navigationDestination(for: Workout.self) { workout in
                    WorkoutDetailView(workout: workout, onDelete: delete)
                }
                .deleteWorkoutConfirm($workoutToDelete, onDelete: delete)
                .toast($toast)
        }
        .onChange(of: justFinished) { path = [] }
    }

    /// Delete Workout, from a row swipe or the detail, which closes onto the list.
    private func delete(_ workout: Workout) {
        path = []
        do {
            try workout.delete()
        } catch {
            fatalError("Could not delete the Workout: \(error)")
        }
        toast = "Workout deleted"
    }
}

/// The week sections, or the empty state. Its own view, so a toast, a confirm or a push doesn't recount every week.
private struct HistoryList: View {
    let justFinished: UUID?
    @Binding var workoutToDelete: Workout?
    @Query(filter: #Predicate<Workout> { $0.endedAt != nil }, sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    @State private var highlighted: UUID?

    var body: some View {
        if workouts.isEmpty {
            Text("No Workouts yet. Tap Start Workout to log your first one.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            list
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(DisplayFormat.historyWeeks(workouts), id: \.start) { week in
                    weekSection(start: week.start, workouts: week.workouts)
                }
            }
            .listStyle(.plain)
            .onChange(of: justFinished, initial: true) { _, id in
                guard let id else { return }
                highlighted = id
                withAnimation { proxy.scrollTo(id, anchor: .top) }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { highlighted = nil }
                }
            }
        }
    }

    /// A sticky week header with its counts, then the week's Workouts.
    private func weekSection(start: Date, workouts: [Workout]) -> some View {
        let sets = workouts.map(\.workingSetCount).reduce(0, +)
        return Section {
            ForEach(workouts) { workout in
                NavigationLink(value: workout) {
                    row(workout)
                }
                .id(workout.id)
                .listRowBackground(highlighted == workout.id ? Color.accentColor.opacity(0.2) : nil)
                .swipeActions {
                    Button("Delete", role: .destructive) { workoutToDelete = workout }
                }
            }
        } header: {
            HStack {
                Text(DisplayFormat.weekHeading(start))
                Spacer()
                Text("\(DisplayFormat.count(workouts.count, "Workout")), \(DisplayFormat.count(sets, "Set"))")
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The date block, the Workout title, and its start, duration and counts.
    private func row(_ workout: Workout) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(workout.startedAt?.formatted(.dateTime.weekday(.abbreviated)) ?? "")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(workout.startedAt?.formatted(.dateTime.day()) ?? "")
                    .font(.title3.bold())
            }
            .frame(minWidth: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(DisplayFormat.historyLine(workout))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

}
