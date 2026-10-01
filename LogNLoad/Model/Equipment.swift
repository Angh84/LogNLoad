enum Equipment: String, Codable, CaseIterable {
    case barbell, dumbbell, kettlebell, machine, cable, band, bodyweight, other

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
}
