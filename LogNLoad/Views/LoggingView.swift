import SwiftUI

/// The Focus logging screen for the Active Workout, shown as the logging cover.
struct LoggingView: View {
    @Bindable var session: LoggingSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ChipPager(session: session)
                ScrollView {
                    if let entry = session.currentEntry, let exercise = entry.exercise {
                        VStack(spacing: 16) {
                            SetCardView(session: session, entry: entry, exercise: exercise)
                            SetsLog(session: session, entry: entry, exercise: exercise)
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Minimize", systemImage: "chevron.down") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    ElapsedTimer(workout: session.workout)
                        .font(.headline.monospacedDigit())
                }
            }
            .sheet(isPresented: $session.isPickerPresented) {
                ExercisePickerView(session: session)
            }
        }
    }
}

/// "m:ss", then "h:mm:ss" from an hour, counting from `startedAt`. Updates by itself.
struct ElapsedTimer: View {
    let workout: Workout

    var body: some View {
        Text(timerInterval: (workout.startedAt ?? .now)...Date.distantFuture, countsDown: false)
    }
}

/// One chip per Entry with a bar per Set, then a "+" chip that opens the picker.
private struct ChipPager: View {
    let session: LoggingSession

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(session.workout.sortedEntries) { entry in
                        chip(entry)
                    }
                    Button { session.isPickerPresented = true } label: {
                        Label("Add Exercise", systemImage: "plus")
                            .labelStyle(.iconOnly)
                            .font(.headline)
                            .foregroundStyle(.tint)
                            .frame(minWidth: 48, maxHeight: .infinity)
                            .background(.background.secondary, in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .scrollIndicators(.hidden)
            .onChange(of: session.currentEntry, initial: true) { _, entry in
                guard let entry else { return }
                withAnimation { proxy.scrollTo(entry.id) }
            }
        }
    }

    private func chip(_ entry: ExerciseEntry) -> some View {
        Button { session.select(entry) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.exercise?.name ?? "")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 3) {
                    ForEach(entry.sortedSets) { set in
                        Capsule()
                            .fill(set.isTarget ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.green))
                            .frame(width: 12, height: 4)
                    }
                }
            }
            .frame(maxWidth: 170, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.background.secondary, in: .rect(cornerRadius: 12))
            .overlay {
                if entry == session.currentEntry {
                    RoundedRectangle(cornerRadius: 12).strokeBorder(.tint, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .id(entry.id)
    }
}

/// Every Set of the current Entry; tapping a row makes that Set current.
private struct SetsLog: View {
    let session: LoggingSession
    let entry: ExerciseEntry
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sets")
                .font(.headline)
                .padding(.vertical, 8)
            ForEach(entry.sortedSets) { set in
                Divider()
                Button { session.select(set) } label: {
                    row(set)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .background(.background.secondary, in: .rect(cornerRadius: 16))
    }

    private func row(_ set: WorkoutSet) -> some View {
        HStack(spacing: 10) {
            Text(entry.label(of: set))
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 28)
            Text(DisplayFormat.set(set, of: exercise))
                .foregroundStyle(set.isTarget ? .secondary : .primary)
            Spacer()
            if let rir = set.rir {
                Text("RIR \(DisplayFormat.rir(rir))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "checkmark")
                .foregroundStyle(.green)
                .opacity(set.isTarget ? 0 : 1)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(set == session.currentSet ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 8))
        .contentShape(.rect)
    }
}
