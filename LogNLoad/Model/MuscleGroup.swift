/// Raw values are the stored keys and never change, even when a display name does.
/// `allCases` is the list order.
enum MuscleGroup: String, Codable, CaseIterable {
    case upperChest, lowerChest
    case frontDelts, sideDelts, rearDelts, rotatorCuff
    case lats, upperBack, traps, lowerBack
    case biceps, brachialis, triceps, forearms
    case abs, obliques
    case quads, hamstrings, glutes, adductors, abductors, calves

    var name: String {
        switch self {
        case .upperChest: "Upper Chest"
        case .lowerChest: "Lower Chest"
        case .frontDelts: "Front Delts"
        case .sideDelts: "Side Delts"
        case .rearDelts: "Rear Delts"
        case .rotatorCuff: "Rotator Cuff"
        case .lats: "Lats"
        case .upperBack: "Upper Back"
        case .traps: "Traps"
        case .lowerBack: "Lower Back"
        case .biceps: "Biceps"
        case .brachialis: "Brachialis"
        case .triceps: "Triceps"
        case .forearms: "Forearms"
        case .abs: "Abs"
        case .obliques: "Obliques"
        case .quads: "Quads"
        case .hamstrings: "Hamstrings"
        case .glutes: "Glutes"
        case .adductors: "Adductors"
        case .abductors: "Abductors"
        case .calves: "Calves"
        }
    }

    var bodyArea: BodyArea {
        switch self {
        case .upperChest, .lowerChest: .chest
        case .frontDelts, .sideDelts, .rearDelts, .rotatorCuff: .shoulders
        case .lats, .upperBack, .traps, .lowerBack: .back
        case .biceps, .brachialis, .triceps, .forearms: .arms
        case .abs, .obliques: .core
        case .quads, .hamstrings, .glutes, .adductors, .abductors, .calves: .legs
        }
    }
}

/// A value inside Exercise `muscleEmphases`, not an entity (ADR-0004).
/// A field added later must be optional or decode with a default.
struct MuscleEmphasis: Codable, Hashable {
    var muscleGroup: MuscleGroup
    /// 0.0 to 1.0, where 1.0 is a full direct Set.
    var weight: Double
}

/// A display grouping only, never stored. `allCases` is the list order.
enum BodyArea: CaseIterable {
    case chest, shoulders, back, arms, core, legs

    var name: String {
        switch self {
        case .chest: "Chest"
        case .shoulders: "Shoulders"
        case .back: "Back"
        case .arms: "Arms"
        case .core: "Core"
        case .legs: "Legs"
        }
    }

    var muscleGroups: [MuscleGroup] {
        MuscleGroup.allCases.filter { $0.bodyArea == self }
    }
}
