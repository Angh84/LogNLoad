import SwiftUI

/// What finishing keeps and removes, and the end-time choice when the last Completed Set is more than 15 minutes old.
struct FinishSheet: View {
    let workout: Workout
    /// The tap time of "Finish", which is "Now".
    let tappedAt: Date
    let onFinish: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var endsAtLastSet = true

    var body: some View {
        let lastSetAt = workout.endTimeChoice(at: tappedAt)
        let end = endsAtLastSet ? lastSetAt ?? tappedAt : tappedAt
        let start = workout.startedAt ?? tappedAt
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(DisplayFormat.duration(from: start, to: end))
                        .font(.largeTitle.bold())
                    Text((start..<max(start, end)).formatted(.interval.hour().minute()))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    tile(DisplayFormat.count(exerciseCount, "Exercise"))
                    tile(setCount)
                }
                ForEach(warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let lastSetAt {
                    Picker("End time", selection: $endsAtLastSet) {
                        Text("Last Set \(DisplayFormat.time(lastSetAt, now: tappedAt))").tag(true)
                        Text("Now \(DisplayFormat.time(tappedAt, now: tappedAt))").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                VStack(spacing: 8) {
                    Button { onFinish(end) } label: {
                        Text("Finish Workout").font(.headline).foregroundStyle(.black).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button { dismiss() } label: {
                        Text("Keep Logging").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
            }
            .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
    }

    private func tile(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(.background.secondary, in: .rect(cornerRadius: 14))
    }

    /// Entries with at least one Completed Set.
    private var exerciseCount: Int {
        workout.sortedEntries.count(where: \.hasCompletedSet)
    }

    /// Completed Working Sets, with "+ N warm-up" for completed Warm-up Sets.
    private var setCount: String {
        let completed = workout.completedSets
        let warmUps = completed.count(where: \.isWarmUp)
        return DisplayFormat.count(completed.count - warmUps, "Set") + (warmUps > 0 ? " + \(warmUps) warm-up" : "")
    }

    private var warnings: [String] {
        var warnings: [String] = []
        let targets = workout.targetSets.count
        if targets > 0 {
            warnings.append(DisplayFormat.count(targets, "target Set") + " not completed will be removed")
        }
        let removed = workout.sortedEntries.filter { !$0.hasCompletedSet }.compactMap(\.exercise?.name)
        if !removed.isEmpty {
            // The UI is English only, so the names are joined in English whatever the Region.
            let names = removed.formatted(.list(type: .and).locale(Locale(identifier: "en_GB")))
            warnings.append("\(names) \(removed.count == 1 ? "has" : "have") no completed Sets and will be removed")
        }
        return warnings
    }
}
