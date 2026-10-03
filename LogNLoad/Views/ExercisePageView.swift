import SwiftData
import SwiftUI

/// An Exercise: its details, note, Muscle Groups, tiles and history of finished Workouts.
struct ExercisePageView: View {
    let exercise: Exercise
    @Query(filter: #Predicate<Workout> { $0.endedAt == nil }) private var activeWorkouts: [Workout]

    var body: some View {
        let history = exercise.finishedHistory
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(DisplayFormat.exerciseDetails(exercise))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if activeWorkouts.first?.contains(exercise) == true {
                        Text("In your current Workout")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.green.opacity(0.15), in: .capsule)
                    }
                    if let note = exercise.note {
                        Text(note)
                    }
                }
            }
            Section("Muscle Groups") {
                ForEach(exercise.emphasesInDisplayOrder, id: \.muscleGroup) { emphasis in
                    HStack {
                        Text(emphasis.muscleGroup.name)
                            .frame(width: 110, alignment: .leading)
                        Capsule()
                            .fill(.tint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .scaleEffect(x: emphasis.weight, anchor: .leading)
                            .frame(height: 6)
                        Text(emphasis.weight.formatted(.number.precision(.fractionLength(1...2))))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                HStack(spacing: 8) {
                    tile("Workouts", "\(history.count)")
                    tile("Last", history.first?.workout?.startedAt.map { DisplayFormat.shortDate($0) } ?? "\u{2013}")
                    tile("First", history.last?.workout?.startedAt.map { DisplayFormat.shortDate($0) } ?? "\u{2013}")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            if history.isEmpty {
                Text("Not in a finished Workout yet. Its Sets show up here once you finish one.")
                    .foregroundStyle(.secondary)
            }
            ForEach(DisplayFormat.historyMonths(history), id: \.month) { month in
                Section(DisplayFormat.monthHeading(month.month)) {
                    ForEach(month.entries) { entry in
                        if let workout = entry.workout {
                            NavigationLink(value: workout) { row(entry, in: workout) }
                        }
                    }
                }
            }
        }
        .navigationTitle(exercise.name ?? "")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("Edit", value: ExerciseFormRoute.edit(exercise))
            }
        }
    }

    /// The date block, the Workout title, and every Set of the Entry, Warm-up Sets included.
    private func row(_ entry: ExerciseEntry, in workout: Workout) -> some View {
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
                Text(DisplayFormat.summary(of: entry.sortedSets, of: exercise))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func tile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background.secondary, in: .rect(cornerRadius: 14))
    }
}
