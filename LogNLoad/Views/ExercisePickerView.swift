import SwiftData
import SwiftUI

/// Picks an Exercise to add to the Active Workout: "In this Workout", "Recent" and "All Exercises", or creates one
/// when the search names none. Archived Exercises are not offered; a search naming one offers to unarchive it. In swap
/// mode it offers only Compatible Exercises, with no Create or Unarchive row.
struct ExercisePickerView: View {
    let session: LoggingSession
    /// Edit mode's "Swap Exercise": the Entry whose Exercise is being replaced.
    var swappingEntry: ExerciseEntry?
    @Query(filter: #Predicate<Exercise> { $0.isArchived == false }) private var exercises: [Exercise]
    @State private var search = ""
    /// Fixed while the picker is open, since picking closes it.
    @State private var recent: [Exercise] = []
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// A swap onto an Exercise already in the Workout, waiting for "Combine with <Y>?".
    @State private var combiningWith: Exercise?
    /// The Exercise being swapped away, as it was when the picker opened, so the offer holds while it closes.
    @State private var swappedFrom: Exercise?

    /// Where names are checked: an edit session's new Exercises live in its own context until Done.
    private var names: ModelContext {
        session.workout.modelContext ?? context
    }

    var body: some View {
        NavigationStack {
            List {
                if swappingEntry == nil, let name = trimmed(search) {
                    if let named = Exercise.named(name, in: names) {
                        if named.isArchived {
                            Button("Unarchive \(named.name ?? "")", systemImage: "tray.and.arrow.up") { unarchive(named) }
                        }
                    } else {
                        NavigationLink {
                            ExerciseFormView(name: name) { exercise in
                                session.create(exercise)
                                dismiss()
                            } onUnarchive: { exercise in
                                unarchive(exercise)
                            }
                            .environment(\.modelContext, names)
                        } label: {
                            Label("Create \"\(name)\"", systemImage: "plus")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                section("In this Workout", offered(session.workout.exercises))
                section("Recent", offered(recent))
                section("All Exercises", offered(exercises).sorted { ($0.name ?? "").localizedStandardCompare($1.name ?? "") == .orderedAscending })
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Exercises")
            .onAppear {
                swappedFrom = swappingEntry?.exercise
                recent = Exercise.recent(for: session.workout, in: context, where: isOffered)
            }
            .navigationTitle(swappingEntry == nil ? "Add Exercise" : "Swap Exercise")
            .alert(
                "Combine with \(combiningWith?.name ?? "")?",
                isPresented: Binding { combiningWith != nil } set: { if !$0 { combiningWith = nil } },
                presenting: combiningWith
            ) { exercise in
                Button("Cancel", role: .cancel) {}
                Button("Combine") { swap(to: exercise) }
            } message: { exercise in
                Text("\(exercise.name ?? "") is already in this Workout. Its Entry keeps the earlier position, the Sets from \(swappedFrom?.name ?? "") are added after its own, and the notes are joined.")
            }
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
                        pick(exercise)
                    } label: {
                        row(exercise)
                    }
                    .tint(.primary)
                }
            }
        }
    }

    private func unarchive(_ exercise: Exercise) {
        session.unarchiveAndAdd(exercise)
        dismiss()
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

    /// Every Exercise in add mode; in swap mode only the Compatible ones (data-model.md), the Entry's own left out.
    private func offered(_ exercises: [Exercise]) -> [Exercise] {
        exercises.filter(isOffered)
    }

    private func isOffered(_ exercise: Exercise) -> Bool {
        guard swappingEntry != nil else { return true }
        guard let swappedFrom else { return false }
        return exercise.id != swappedFrom.id && exercise.isCompatible(with: swappedFrom)
    }

    private func pick(_ exercise: Exercise) {
        guard swappingEntry != nil else {
            session.add(exercise)
            dismiss()
            return
        }
        if session.workout.contains(exercise) {
            combiningWith = exercise
        } else {
            swap(to: exercise)
        }
    }

    private func swap(to exercise: Exercise) {
        guard let swappingEntry else { return }
        session.swap(swappingEntry, to: exercise)
        dismiss()
    }
}
