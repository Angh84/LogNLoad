import SwiftUI

/// The Focus logging screen for the Active Workout, shown as the logging cover.
struct LoggingView: View {
    @Bindable var session: LoggingSession
    let onFinish: () -> Void
    let onDiscard: () -> Void
    @Environment(\.dismiss) private var dismiss
    /// The tap time of "Finish", the end time unless the user picks the last Set's.
    @State private var finishTappedAt = Date.now
    @State private var isFinishing = false
    @State private var isDiscardingUncompleted = false
    @State private var isConfirmingDiscard = false
    @State private var isShowingOverview = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ChipPager(session: session) { isShowingOverview = true }
                if let entry = session.currentEntry, let exercise = entry.exercise {
                    List {
                        SetCardView(session: session, entry: entry, exercise: exercise)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        SetsLog(session: session, entry: entry, exercise: exercise)
                    }
                    .listSectionSpacing(16)
                } else {
                    emptyWorkout
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: tapFinish) {
                        Text("Finish").fontWeight(.semibold).foregroundStyle(.black)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .sheet(isPresented: $session.isPickerPresented) {
                ExercisePickerView(session: session)
            }
            .sheet(isPresented: $isShowingOverview) {
                OverviewSheet(session: session, onDiscard: discard)
            }
            .sheet(isPresented: $isFinishing) {
                FinishSheet(workout: session.workout, tappedAt: finishTappedAt, onFinish: finish)
            }
            .alert("Discard this Workout?", isPresented: $isDiscardingUncompleted) {
                Button("Keep Logging", role: .cancel) {}
                Button("Discard", role: .destructive, action: discard)
            } message: {
                Text("No Sets are completed, so there is nothing to save.")
            }
            .alert("Workout still open", isPresented: isStalePromptUp, presenting: session.stalePromptAt) { now in
                if let lastSetAt = session.workout.lastCompletedAt {
                    Button("Finish at \(DisplayFormat.time(lastSetAt, now: now))") { finish(at: lastSetAt) }
                    Button("Resume", role: .cancel) { session.resume(at: .now) }
                    Button("Discard", role: .destructive) { isConfirmingDiscard = true }
                } else {
                    Button("Resume", role: .cancel) { session.resume(at: .now) }
                    Button("Discard", role: .destructive, action: discard)
                }
            } message: { now in
                Text(staleMessage(now: now))
            }
            .discardWorkoutConfirm(isPresented: $isConfirmingDiscard, workout: session.workout, onDiscard: discard)
            // The stale prompt goes on top, so whatever else is up closes first.
            .onChange(of: session.stalePromptAt != nil, initial: true) { _, isUp in
                guard isUp else { return }
                session.isPickerPresented = false
                isShowingOverview = false
                isFinishing = false
                isDiscardingUncompleted = false
                isConfirmingDiscard = false
            }
        }
    }

    private var emptyWorkout: some View {
        VStack(spacing: 16) {
            Text("Add your first Exercise to start logging.")
                .font(.headline)
                .multilineTextAlignment(.center)
            Button { session.isPickerPresented = true } label: {
                Text("Add Exercise").foregroundStyle(.black)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }

    /// With zero Completed Sets there is nothing to finish, so it offers to discard instead.
    private func tapFinish() {
        finishTappedAt = .now
        if session.workout.completedSets.isEmpty {
            isDiscardingUncompleted = true
        } else {
            isFinishing = true
        }
    }

    private func finish(at end: Date) {
        session.finish(at: end)
        onFinish()
    }

    private func discard() {
        session.discard()
        onDiscard()
    }

    private var isStalePromptUp: Binding<Bool> {
        Binding { session.stalePromptAt != nil } set: { if !$0 { session.stalePromptAt = nil } }
    }

    private func staleMessage(now: Date) -> String {
        let workout = session.workout
        guard let lastSetAt = workout.lastCompletedAt else {
            let start = workout.startedAt ?? now
            return "You started it at \(DisplayFormat.time(start, now: now)), \(DisplayFormat.ago(from: start, to: now)), and completed no Sets."
        }
        let message = "Your last Set was at \(DisplayFormat.time(lastSetAt, now: now)), \(DisplayFormat.ago(from: lastSetAt, to: now))."
        let targets = workout.targetSets.count
        guard targets > 0 else { return message }
        return message + " Finishing removes \(DisplayFormat.count(targets, "target Set")) not completed."
    }

}

extension View {
    /// Shows `message` at the top for 2 seconds, then clears it.
    func toast(_ message: Binding<String?>) -> some View {
        overlay(alignment: .top) {
            VStack {
                if let text = message.wrappedValue {
                    Text(text)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: .capsule)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.default, value: message.wrappedValue)
        }
        .task(id: message.wrappedValue) {
            guard let shown = message.wrappedValue else { return }
            try? await Task.sleep(for: .seconds(2))
            // A newer message cancels this timer and stays; leaving the screen cancels it and clears this one.
            if message.wrappedValue == shown { message.wrappedValue = nil }
        }
    }

    /// The "Delete this Workout?" confirm, from a History row swipe and the Workout detail. Set `workout` to ask.
    func deleteWorkoutConfirm(_ workout: Binding<Workout?>, onDelete: @escaping (Workout) -> Void) -> some View {
        alert(
            "Delete this Workout?",
            isPresented: Binding { workout.wrappedValue != nil } set: { if !$0 { workout.wrappedValue = nil } },
            presenting: workout.wrappedValue
        ) { workout in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete(workout) }
        } message: { _ in
            Text("It's removed from history and from Health. This can't be undone.")
        }
    }

    /// The "Discard Workout?" confirm, from the overview sheet and the stale prompt. N counts the Completed Sets,
    /// Warm-up Sets included.
    func discardWorkoutConfirm(isPresented: Binding<Bool>, workout: Workout, onDiscard: @escaping () -> Void) -> some View {
        alert("Discard Workout?", isPresented: isPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Discard", role: .destructive, action: onDiscard)
        } message: {
            let completed = workout.completedSets.count
            Text(completed == 0
                ? "This deletes the Workout. Nothing is saved to history or Health."
                : "This deletes the Workout and its \(DisplayFormat.count(completed, "Set")). Nothing is saved to history or Health.")
        }
    }

    /// "Remove <name>?" for the Entry `LoggingSession.requestRemoval(of:)` returns.
    func removeExerciseConfirm(_ entry: Binding<ExerciseEntry?>, session: LoggingSession) -> some View {
        alert(
            "Remove \(entry.wrappedValue?.exercise?.name ?? "")?",
            isPresented: Binding { entry.wrappedValue != nil } set: { if !$0 { entry.wrappedValue = nil } },
            presenting: entry.wrappedValue
        ) { entry in
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) { session.remove(entry) }
        } message: { entry in
            Text("Its \(DisplayFormat.count(entry.completedSets.count, "completed Set")) will be deleted.")
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

/// The list button that opens the overview sheet, one chip per Entry with a bar per Set, then a "+" chip that
/// opens the picker.
private struct ChipPager: View {
    let session: LoggingSession
    let onOverview: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    iconChip("Overview", systemImage: "list.bullet", action: onOverview)
                    ForEach(session.workout.sortedEntries) { entry in
                        chip(entry)
                    }
                    iconChip("Add Exercise", systemImage: "plus") { session.isPickerPresented = true }
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

    private func iconChip(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.headline)
                .foregroundStyle(.tint)
                .frame(minWidth: 48, minHeight: 44, maxHeight: .infinity)
                .background(.background.secondary, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
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

/// Every Set of the current Entry: tap a row to make it current, swipe it to delete, long-press and drag to reorder.
private struct SetsLog: View {
    let session: LoggingSession
    let entry: ExerciseEntry
    let exercise: Exercise

    var body: some View {
        Section {
            ForEach(entry.sortedSets) { set in
                Button { session.select(set) } label: {
                    row(set)
                }
                .buttonStyle(.plain)
                .listRowBackground(Rectangle().fill(set == session.currentSet ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.background.secondary)))
            }
            .onDelete { offsets in
                let sets = entry.sortedSets
                offsets.map { sets[$0] }.forEach(session.delete)
            }
            .onMove { session.moveSets(fromOffsets: $0, toOffset: $1) }
        } header: {
            HStack {
                Text("Sets")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button("Add Set", systemImage: "plus", action: session.addSet)
                    .font(.subheadline.weight(.semibold))
            }
            .textCase(nil)
        }
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
        .contentShape(.rect)
    }
}
