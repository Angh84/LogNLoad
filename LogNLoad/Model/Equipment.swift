enum Equipment: String, Codable, CaseIterable {
    case barbell, dumbbell, kettlebell, machine, cable, band, bodyweight, other

    var name: String {
        switch self {
        case .barbell: "Barbell"
        case .dumbbell: "Dumbbell"
        case .kettlebell: "Kettlebell"
        case .machine: "Machine"
        case .cable: "Cable"
        case .band: "Band"
        case .bodyweight: "Bodyweight"
        case .other: "Other"
        }
    }

    var weightConvention: WeightConvention {
        switch self {
        case .dumbbell, .kettlebell: .perImplement
        case .barbell, .machine, .cable, .band, .bodyweight, .other: .total
        }
    }
}

enum WeightConvention {
    case perImplement, total
}

enum LoadType: String, Codable, CaseIterable {
    case loaded, bodyweight, assisted

    var name: String {
        switch self {
        case .loaded: "Loaded"
        case .bodyweight: "Bodyweight"
        case .assisted: "Assisted"
        }
    }
}
