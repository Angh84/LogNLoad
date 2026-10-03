import SwiftData
import SwiftUI

/// The History tab's root: every finished Workout, newest first, in week sections.
struct HistoryView: View {
    /// The Workout just finished, which the list lands on and highlights briefly.
    let justFinished: UUID?
    @State private var path = NavigationPath()
    @State private var workoutToDelete: Workout?
    @State private var toast: String?
    @Environment(\.modelContext) private var context
    @Environment(HealthSync.self) private var health

    var body: some View {
        NavigationStack(path: $path) {
            HistoryList(justFinished: justFinished, workoutToDelete: $workoutToDelete)
                .navigationTitle("History")
                .sharedDestinations(path: $path, toast: $toast, onDeleteWorkout: delete)
                .deleteWorkoutConfirm($workoutToDelete, onDelete: delete)
        }
        // Over the whole stack, so it shows on the screen a deleted Workout's detail closes onto.
        .toast($toast)
        .onChange(of: justFinished) { path = NavigationPath() }
    }

    /// Delete Workout, from a row swipe or a detail. The detail closes itself once its Workout is gone.
    private func delete(_ workout: Workout) {
        do {
            try workout.delete()
        } catch {
            fatalError("Could not delete the Workout: \(error)")
        }
        toast = "Workout deleted"
        Task { await health.sync(in: context) }
    }
}

/// The week sections, or the empty state. Its own view, so a toast, a confirm or a push doesn't recount every week.
private struct HistoryList: View {
    let justFinished: UUID?
    @Binding var workoutToDelete: Workout?
    @Query(filter: #Predicate<Workout> { $0.endedAt != nil }, sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    @State private var highlighted: UUID?
    @State private var month = HistoryCalendarView.monthStart(of: .now)

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
                // The spec's fallback for the collapsing week strip: the grid scrolls away as the list's header.
                HistoryCalendarView(month: $month, workouts: workouts) { workout in
                    withAnimation { proxy.scrollTo(workout.id, anchor: .top) }
                } onPage: { month in
                    if let target = DisplayFormat.pagingTarget(month, workouts: workouts) {
                        withAnimation { proxy.scrollTo(target.id, anchor: .top) }
                    }
                }
                .id(Self.calendarID)
                .listRowSeparator(.hidden)
                ForEach(DisplayFormat.historyWeeks(workouts), id: \.start) { week in
                    weekSection(start: week.start, workouts: week.workouts)
                }
            }
            .listStyle(.plain)
            .onChange(of: justFinished, initial: true) { _, id in
                guard let id else { return }
                highlighted = id
                month = HistoryCalendarView.monthStart(of: workouts.first { $0.id == id }?.startedAt ?? .now)
                withAnimation { proxy.scrollTo(Self.calendarID, anchor: .top) }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { highlighted = nil }
                }
            }
        }
    }

    private static let calendarID = "calendar"

    /// A sticky week header with its counts, then the week's Workouts.
    private func weekSection(start: Date, workouts: [Workout]) -> some View {
        Section {
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
                Text(DisplayFormat.workoutCounts(workouts))
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
