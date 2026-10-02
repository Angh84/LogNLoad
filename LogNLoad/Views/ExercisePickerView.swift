import SwiftData
import SwiftUI

/// Picks an Exercise to add to the Active Workout. Archived Exercises are not offered.
struct ExercisePickerView: View {
    let session: LoggingSession
    @Query(filter: #Predicate<Exercise> { $0.isArchived == false }) private var exercises: [Exercise]
    @State private var search = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("All Exercises") {
                    ForEach(matches) { exercise in
                        Button(exercise.name ?? "") {
                            session.add(exercise)
                            dismiss()
                        }
                        .tint(.primary)
                    }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }

    /// A-Z, narrowed by the search.
    private var matches: [Exercise] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return exercises
            .filter { query.isEmpty || ($0.name ?? "").localizedStandardContains(query) }
            .sorted { ($0.name ?? "").localizedStandardCompare($1.name ?? "") == .orderedAscending }
    }
}
