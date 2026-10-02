import SwiftUI

/// The card: the Exercise with its "..." menu and notes, the current Set with its steppers, chips and the Set
/// loop's actions, or the no-target state.
struct SetCardView: View {
    let session: LoggingSession
    let entry: ExerciseEntry
    let exercise: Exercise
    @State private var completions = 0
    @FocusState private var isTypingWeight: Bool
    @State private var isEditingEntryNote = false
    @State private var isEditingSetNote = false
    @State private var noteDraft = ""
    @State private var entryToRemove: ExerciseEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(exercise.name ?? "")
                    .font(.title2.bold())
                Spacer()
                exerciseMenu
            }
            if let note = exercise.note {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let note = entry.note {
                Label(note, systemImage: "note.text")
                    .font(.subheadline)
            }
            if let set = session.currentSet {
                Text(entry.title(of: set))
                    .font(.subheadline.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                WeightStepper(label: DisplayFormat.weightLabel(for: exercise), weight: set.weight, isTyping: $isTypingWeight) {
                    session.changeWeight(to: $0)
                }
                if exercise.isUnilateral {
                    RepsStepper(label: "Left", name: "left reps", reps: set.repsLeft) { session.changeReps(\.repsLeft, to: $0) }
                    RepsStepper(label: "Right", name: "right reps", reps: set.repsRight) { session.changeReps(\.repsRight, to: $0) }
                } else {
                    RepsStepper(label: "Reps", name: "reps", reps: set.reps) { session.changeReps(\.reps, to: $0) }
                }
                chips(for: set)
                if let note = set.note {
                    Label(note, systemImage: "note.text")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                actions(for: set)
            } else {
                noTargetState
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background.secondary, in: .rect(cornerRadius: 22))
        .sensoryFeedback(.success, trigger: completions)
        .onChange(of: session.currentSet) { isTypingWeight = false }
        .alert(entry.note == nil ? "Add note" : "Edit note", isPresented: $isEditingEntryNote) {
            TextField("Note", text: $noteDraft)
            Button("Cancel", role: .cancel) {}
            Button("Save") { session.changeNote(to: noteDraft, of: entry) }
        }
        .alert("Set note", isPresented: $isEditingSetNote) {
            TextField("Note", text: $noteDraft)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let set = session.currentSet { session.changeNote(to: noteDraft, of: set) }
            }
        }
        .removeExerciseConfirm($entryToRemove, session: session)
        // The stale prompt goes on top, so the card's own alerts close first.
        .onChange(of: session.stalePromptAt != nil) { _, isUp in
            guard isUp else { return }
            isEditingEntryNote = false
            isEditingSetNote = false
            entryToRemove = nil
        }
    }

    private var exerciseMenu: some View {
        Menu {
            Button(entry.note == nil ? "Add note" : "Edit note", systemImage: "note.text") {
                noteDraft = entry.note ?? ""
                isEditingEntryNote = true
            }
            if session.isEditing {
                Button("Swap Exercise", systemImage: "arrow.left.arrow.right") { session.swappingEntry = entry }
            }
            Button("Remove Exercise", systemImage: "trash", role: .destructive) {
                entryToRemove = session.requestRemoval(of: entry)
            }
        } label: {
            Label("Exercise options", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
                .font(.title3)
        }
    }

    /// "Warm-up", "Set note", and the RIR chip on a Completed Working Set.
    private func chips(for set: WorkoutSet) -> some View {
        HStack(spacing: 8) {
            Button { session.toggleWarmUp() } label: {
                Chip(title: "Warm-up", isOn: set.isWarmUp)
            }
            Button {
                noteDraft = set.note ?? ""
                isEditingSetNote = true
            } label: {
                Chip(title: "Set note", isOn: set.note != nil)
            }
            if !set.isTarget && set.isWorkingSet {
                Menu {
                    ForEach(0...4, id: \.self) { rir in
                        Button(DisplayFormat.rir(rir)) { session.changeRIR(to: rir) }
                    }
                    Button("None") { session.changeRIR(to: nil) }
                } label: {
                    Chip(title: set.rir.map { "RIR \(DisplayFormat.rir($0))" } ?? "RIR", isOn: set.rir != nil)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func actions(for set: WorkoutSet) -> some View {
        if session.isEditing {
            editActions(for: set)
        } else if session.isAskingRIR {
            VStack(alignment: .leading, spacing: 10) {
                Text("Reps in reserve?")
                    .font(.headline)
                HStack(spacing: 6) {
                    ForEach(0...4, id: \.self) { rir in
                        Button { session.recordRIR(rir) } label: {
                            Text(DisplayFormat.rir(rir))
                                .font(.headline)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(.quaternary, in: .rect(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button { session.recordRIR(nil) } label: {
                    Text("Skip").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
            }
            .padding(14)
            .background(.tint.opacity(0.15), in: .rect(cornerRadius: 16))
        } else if set.isTarget {
            Button {
                completions += 1
                isTypingWeight = false
                session.complete(at: .now)
            } label: {
                Label("Complete Set", systemImage: "checkmark")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
        } else {
            HStack(spacing: 8) {
                Button { session.undoCompletion() } label: {
                    Text("Undo completion").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button { session.nextSet() } label: {
                    Text("Next Set").foregroundStyle(.black).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
    }

    private var noTargetState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text(entry.noTargetHeading)
                .font(.headline)
            HStack(spacing: 8) {
                Button("Add Set", action: session.addSet)
                    .buttonStyle(.bordered)
                onwardButton
            }
            .lineLimit(1)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
    }

    /// Edit mode: every Set is completed, so no Complete Set; "Add Set", then the following Set or onward.
    private func editActions(for set: WorkoutSet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(set.completedAt.map { "Completed \($0.formatted(.dateTime.hour().minute()))" } ?? "Completed, time unknown")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button("Add Set", action: session.addSet)
                    .buttonStyle(.bordered)
                if session.followingSet != nil {
                    Button { session.nextSet() } label: {
                        Text("Next Set").foregroundStyle(.black).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    onwardButton
                }
            }
            .lineLimit(1)
            .controlSize(.large)
        }
    }

    /// "Next: <Exercise>", or "Add Exercise" on the last Entry.
    private var onwardButton: some View {
        Group {
            if let next = session.nextEntry {
                Button { session.select(next) } label: {
                    Text("Next: \(next.exercise?.name ?? "")").foregroundStyle(.black).frame(maxWidth: .infinity)
                }
            } else {
                Button { session.isPickerPresented = true } label: {
                    Text("Add Exercise").foregroundStyle(.black).frame(maxWidth: .infinity)
                }
            }
        }
        .buttonStyle(.borderedProminent)
    }
}

/// A chip on the card and in the Exercise form, filled with the accent while it is on.
struct Chip: View {
    let title: String
    let isOn: Bool
    var horizontalPadding: CGFloat = 12

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isOn ? AnyShapeStyle(.black) : AnyShapeStyle(.primary))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 7)
            .background(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: .capsule)
    }
}

/// The weight stepper: 2.5 kg per tap, and the number can be typed.
private struct WeightStepper: View {
    static let format = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...2))
    let label: String
    let weight: Double
    var isTyping: FocusState<Bool>.Binding
    let onChange: (Double) -> Void
    @State private var text = ""

    var body: some View {
        BigStepper(label: label, name: "weight", onStep: { step in
            isTyping.wrappedValue = false
            onChange(weight + 2.5 * Double(step))
        }) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("0", text: $text)
                    .accessibilityLabel(label)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                    .focused(isTyping)
                    .onChange(of: text) {
                        // Saved as it is typed, so the value reaches this Set even when the user moves on without "Done".
                        if isTyping.wrappedValue, let kg = try? Double(text, format: Self.format) { onChange(kg) }
                    }
                Text("kg")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: weight, initial: true) {
            if !isTyping.wrappedValue { text = weight.formatted(Self.format) }
        }
        .onChange(of: isTyping.wrappedValue) {
            if !isTyping.wrappedValue { text = weight.formatted(Self.format) }
        }
        .toolbar {
            if isTyping.wrappedValue {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isTyping.wrappedValue = false }
                }
            }
        }
    }
}

/// A reps stepper: 1 per tap.
private struct RepsStepper: View {
    let label: String
    let name: String
    let reps: Int
    let onChange: (Int) -> Void

    var body: some View {
        BigStepper(label: label, name: name, onStep: { onChange(reps + $0) }) {
            Text("\(reps)")
        }
    }
}

/// A label, then a big value between "-" and "+". Each tap gives the selection haptic.
private struct BigStepper<Value: View>: View {
    let label: String
    /// What the "-" and "+" accessibility labels name, e.g. "weight".
    let name: String
    let onStep: (Int) -> Void
    @ViewBuilder let value: Value
    @State private var taps = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                step(-1, "Decrease \(name)", systemImage: "minus")
                Spacer()
                value
                    .font(.system(.largeTitle, design: .rounded).bold().monospacedDigit())
                Spacer()
                step(1, "Increase \(name)", systemImage: "plus")
            }
        }
        .sensoryFeedback(.selection, trigger: taps)
    }

    private func step(_ direction: Int, _ title: String, systemImage: String) -> some View {
        Button {
            taps += 1
            onStep(direction)
        } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(width: 32, height: 32)
        }
        .font(.title2.bold())
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .controlSize(.large)
    }
}
