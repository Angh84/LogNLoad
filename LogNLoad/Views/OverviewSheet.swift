import SwiftUI

/// The Workout name and note, every Entry with its Completed Sets, and "Discard Workout" (not in edit mode).
struct OverviewSheet: View {
    let session: LoggingSession
    let onDiscard: () -> Void
    @Environment(\.dismiss) private var dismiss
    /// What is typed, which keeps spaces the store trims away.
    @State private var name: String
    @State private var note: String
    @State private var entryToRemove: ExerciseEntry?
    @State private var isConfirmingDiscard = false

    init(session: LoggingSession, onDiscard: @escaping () -> Void) {
        self.session = session
        self.onDiscard = onDiscard
        _name = State(initialValue: session.workout.name ?? "")
        _note = State(initialValue: session.workout.note ?? "")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Workout name", text: $name)
                    TextField("Note", text: $note, axis: .vertical)
                }
                Section {
                    ForEach(session.workout.sortedEntries) { entry in
                        Button {
                            session.select(entry)
                            dismiss()
                        } label: {
                            row(entry)
                        }
                        .tint(.primary)
                        .swipeActions {
                            Button("Remove", role: .destructive) {
                                entryToRemove = session.requestRemoval(of: entry)
                            }
                        }
                    }
                    .onMove { session.moveEntries(fromOffsets: $0, toOffset: $1) }
                }
                if !session.isEditing {
                    Section {
                        Button("Discard Workout", role: .destructive) { isConfirmingDiscard = true }
                    }
                }
            }
            .onChange(of: name) { session.changeWorkoutName(to: name) }
            .onChange(of: note) { session.changeWorkoutNote(to: note) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .removeExerciseConfirm($entryToRemove, session: session)
            .discardWorkoutConfirm(isPresented: $isConfirmingDiscard, workout: session.workout, onDiscard: onDiscard)
        }
    }

    /// The Exercise, then the compact summary of its Completed Sets, Warm-up Sets included.
    private func row(_ entry: ExerciseEntry) -> some View {
        let completed = entry.completedSets
        return VStack(alignment: .leading, spacing: 4) {
            Text(entry.exercise?.name ?? "")
                .font(.headline)
            Group {
                if let exercise = entry.exercise, !completed.isEmpty {
                    Text(DisplayFormat.summary(of: completed, of: exercise))
                } else {
                    // In edit mode every Set is completed, so an Entry without any has none at all.
                    Text(session.isEditing ? "No Sets" : "No Sets completed")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}
