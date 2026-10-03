import Foundation
import SwiftData

/// The Training Volume per Muscle Group over a set of Workouts (CONTEXT.md).
struct TrainingVolume {
    private var volumes: [MuscleGroup: Double] = [:]

    init(_ workouts: [Workout]) {
        for entry in workouts.flatMap({ $0.entries ?? [] }) {
            let emphases = entry.exercise?.muscleEmphases ?? []
            for set in entry.sets ?? [] where set.isWorkingSet && !set.isTarget {
                for emphasis in emphases {
                    volumes[emphasis.muscleGroup, default: 0] += emphasis.weight
                }
            }
        }
    }

    /// Rounded to one decimal, as shown, so the number and its band always agree.
    subscript(muscleGroup: MuscleGroup) -> Double {
        ((volumes[muscleGroup] ?? 0) * 10).rounded() / 10
    }

    func band(_ muscleGroup: MuscleGroup) -> VolumeBand {
        VolumeBand(self[muscleGroup])
    }

    /// Today and the 6 calendar days before it. Each end is the start of its own day, which daylight saving can move
    /// off midnight.
    static func window(endingOn now: Date, calendar: Calendar) -> DateInterval {
        let first = calendar.date(byAdding: .day, value: -6, to: now) ?? now
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return DateInterval(start: calendar.startOfDay(for: first), end: calendar.startOfDay(for: tomorrow))
    }
}

/// The fixed Training Volume bands the Muscles tab colours by.
enum VolumeBand: CaseIterable {
    case zero, under5, from5, from10, from20

    init(_ volume: Double) {
        self = switch volume {
        case ...0: .zero
        case ..<5: .under5
        case ..<10: .from5
        case ..<20: .from10
        default: .from20
        }
    }

    var label: String {
        switch self {
        case .zero: "0"
        case .under5: "<5"
        case .from5: "5-10"
        case .from10: "10-20"
        case .from20: "20+"
        }
    }
}
