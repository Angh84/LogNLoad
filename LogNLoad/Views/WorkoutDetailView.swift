import SwiftData
import SwiftUI

/// A finished Workout: its tiles and note, one collapsible row per Entry, and "Delete Workout".
struct WorkoutDetailView: View {
    let workout: Workout
    let onDelete: (Workout) -> Void
    /// Not remembered: every visit starts collapsed.
    @State private var expanded: Set<UUID> = []
    @State private var workoutToDelete: Workout?
    @Query(filter: #Predicate<Workout> { $0.endedAt == nil }) private var activeWorkouts: [Workout]
    @State private var editSession: LoggingSession?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Deleted here, deeper in the stack or in the other tab: the detail closes itself when shown.
        if workout.modelContext == nil {
            Color.clear.onAppear { dismiss() }
        } else {
            content
        }
    }

    private var content: some View {
        List {
            if !activeWorkouts.isEmpty {
                Text("Finish or discard your current Workout to edit.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section {
                HStack(spacing: 8) {
                    tile("Duration", value: duration.value, detail: duration.times)
                    tile("Exercises", value: "\(workout.sortedEntries.count)", detail: nil)
                    tile("Sets", value: "\(workout.workingSetCount)", detail: workout.warmUpSetCount > 0 ? "+ \(workout.warmUpSetCount) warm-up" : nil)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                if let note = workout.note {
                    Text(note)
                }
            }
            ForEach(Array(workout.sortedEntries.enumerated()), id: \.element.id) { index, entry in
                Section {
                    entryRows(entry)
                } header: {
                    if index == 0 { exercisesHeader }
                }
            }
            Section {
                Button("Delete Workout", role: .destructive) { workoutToDelete = workout }
            }
        }
        .navigationTitle(workout.name ?? workout.startedAt.map { DisplayFormat.workoutDate($0) } ?? "")
        .navigationSubtitle(workout.name == nil ? workout.sortedEntries.compactMap(\.exercise?.name).joined(separator: ", ") : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editSession = LoggingSession.editing(workout) }
                    .disabled(!activeWorkouts.isEmpty)
            }
        }
        .fullScreenCover(item: $editSession) { session in
            LoggingView(session: session, onDeleteWorkout: { onDelete(workout) })
        }
        .deleteWorkoutConfirm($workoutToDelete, onDelete: onDelete)
    }

    private var exercisesHeader: some View {
        HStack {
            Text("Exercises")
            Spacer()
            let ids = Set(workout.sortedEntries.map(\.id))
            Button(expanded == ids ? "Collapse all" : "Expand all") {
                expanded = expanded == ids ? [] : ids
            }
            .font(.subheadline)
            .textCase(nil)
        }
    }

    /// The collapsed row, then, when expanded, its Sets and the Entry note.
    @ViewBuilder
    private func entryRows(_ entry: ExerciseEntry) -> some View {
        let isExpanded = expanded.contains(entry.id)
        Button {
            if isExpanded { expanded.remove(entry.id) } else { expanded.insert(entry.id) }
        } label: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.exercise?.name ?? "")
                        .font(.headline)
                    if let exercise = entry.exercise {
                        Text(DisplayFormat.summary(of: entry.sortedSets, of: exercise))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if entry.note != nil || entry.sortedSets.contains(where: { $0.note != nil }) {
                    Image(systemName: "note.text")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Has notes")
                }
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .foregroundStyle(.tertiary)
            }
        }
        .tint(.primary)
        if isExpanded, let exercise = entry.exercise {
            ForEach(entry.sortedSets) { set in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 10) {
                        Text(entry.label(of: set))
                            .font(.subheadline.weight(.semibold))
                            .frame(minWidth: 28)
                        Text(DisplayFormat.set(set, of: exercise))
                        Spacer()
                        if let rir = set.rir {
                            Text("RIR \(DisplayFormat.rir(rir))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let note = set.note {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 38)
                    }
                }
            }
            if let note = entry.note {
                Label(note, systemImage: "note.text")
                    .font(.subheadline)
            }
            NavigationLink("Exercise history", value: exercise)
                .font(.subheadline)
        }
    }

    private func tile(_ title: String, value: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
            Text(detail ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background.secondary, in: .rect(cornerRadius: 14))
    }

    private var duration: (value: String, times: String) {
        guard let start = workout.startedAt, let end = workout.endedAt else { return ("", "") }
        return (DisplayFormat.duration(from: start, to: end), (start..<max(start, end)).formatted(.interval.hour().minute()))
    }
}
