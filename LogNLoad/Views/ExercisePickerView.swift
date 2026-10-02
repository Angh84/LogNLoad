import SwiftData
import SwiftUI

/// Picks an Exercise to add to the Active Workout: "In this Workout", "Recent" and "All Exercises", or creates one
/// when the search names none. Archived Exercises are not offered.
struct ExercisePickerView: View {
    let session: LoggingSession
    @Query(filter: #Predicate<Exercise> { $0.isArchived == false }) private var exercises: [Exercise]
    @State private var search = ""
    /// Fixed while the picker is open, since picking closes it.
    @State private var recent: [Exercise] = []
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let name = trimmed(search), Exercise.named(name, in: context) == nil {
                    NavigationLink {
                        ExerciseFormView(name: name) { exercise in
                            session.create(exercise)
                            dismiss()
                        }
                    } label: {
                        Label("Create \"\(name)\"", systemImage: "plus")
                            .foregroundStyle(.tint)
                    }
                }
                section("In this Workout", session.workout.exercises)
                section("Recent", recent)
                section("All Exercises", exercises.sorted { ($0.name ?? "").localizedStandardCompare($1.name ?? "") == .orderedAscending })
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Exercises")
            .onAppear { recent = Exercise.recent(for: session.workout, in: context) }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }

    /// The section's Exercises narrowed by the search; hidden when none are left.
    @ViewBuilder
    private func section(_ title: String, _ exercises: [Exercise]) -> some View {
        let query = trimmed(search)
        let matches = exercises.filter { query.map(($0.name ?? "").localizedStandardContains) ?? true }
        if !matches.isEmpty {
            Section(title) {
                ForEach(matches) { exercise in
                    Button {
                        session.add(exercise)
                        dismiss()
                    } label: {
                        row(exercise)
                    }
                    .tint(.primary)
                }
            }
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(exercise.name ?? "")
                if session.workout.contains(exercise) {
                    Text("In Workout")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: .capsule)
                }
            }
            Text(DisplayFormat.lastPerformance(of: exercise))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
