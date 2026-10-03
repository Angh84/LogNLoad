import SwiftData
import SwiftUI

/// The Muscles tab's root: each Muscle Group's Training Volume over the last 7 days, by Body Area.
struct MusclesView: View {
    @Environment(\.scenePhase) private var scenePhase
    /// Refreshed on appear, on return to the foreground and at midnight, which moves the window once the day has changed.
    @State private var now = Date.now

    var body: some View {
        NavigationStack {
            MusclesList(window: TrainingVolume.window(endingOn: now, calendar: .current))
                .navigationTitle("Muscles")
                .navigationSubtitle("Last 7 days")
        }
        .onAppear { now = .now }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = .now }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .NSCalendarDayChanged) { now = .now }
        }
    }
}

/// Its own view, so its query is rebuilt for each window. Summing in `body` reads every Set and Muscle Emphasis,
/// so completing a Set or editing an Exercise updates it too.
private struct MusclesList: View {
    @Query private var workouts: [Workout]

    init(window: DateInterval) {
        _workouts = Query(filter: Workout.predicate(startedIn: window))
    }

    var body: some View {
        let volume = TrainingVolume(workouts)
        List {
            Section {
                VStack(spacing: 14) {
                    HStack(alignment: .top, spacing: 8) {
                        figureColumn(.front, volume)
                        figureColumn(.back, volume)
                    }
                    legend
                }
                .listRowBackground(Color.clear)
            }
            ForEach(BodyArea.allCases, id: \.self) { area in
                Section(area.name) {
                    ForEach(area.muscleGroups, id: \.self) { group in
                        LabeledContent(group.name) {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(volume.band(group).color)
                                    .frame(width: 11, height: 11)
                                Text(DisplayFormat.trainingVolume(volume[group]))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
    }

    private func figureColumn(_ figure: MuscleFigure, _ volume: TrainingVolume) -> some View {
        VStack(spacing: 4) {
            MuscleFigureView(figure: figure, volume: volume)
            Text(figure.facing.name)
                .font(.caption.smallCaps())
                .foregroundStyle(.secondary)
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(VolumeBand.allCases, id: \.self) { band in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(band.color)
                        .frame(width: 12, height: 12)
                    Text(band.label)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

extension VolumeBand {
    /// Lightest for the fewest Sets, darkest for the most; no Sets is the figure's uncoloured grey.
    var color: Color {
        switch self {
        case .zero: Color(red: 0x2F / 255, green: 0x33 / 255, blue: 0x3B / 255)
        case .under5: Color(red: 0xC4 / 255, green: 0xD5 / 255, blue: 0xF7 / 255)
        case .from5: Color(red: 0x7F / 255, green: 0xA3 / 255, blue: 0xEA / 255)
        case .from10: Color(red: 0x3F / 255, green: 0x72 / 255, blue: 0xDB / 255)
        case .from20: Color(red: 0x1F / 255, green: 0x45 / 255, blue: 0xB0 / 255)
        }
    }
}
