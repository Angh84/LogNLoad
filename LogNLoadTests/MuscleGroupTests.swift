import Testing
@testable import LogNLoad

struct MuscleGroupTests {
    @Test func theRawKeysAreStableCamelCaseInListOrder() {
        #expect(MuscleGroup.allCases.map(\.rawValue) == [
            "upperChest", "lowerChest",
            "frontDelts", "sideDelts", "rearDelts", "rotatorCuff",
            "lats", "upperBack", "traps", "lowerBack",
            "biceps", "brachialis", "triceps", "forearms",
            "abs", "obliques",
            "quads", "hamstrings", "glutes", "adductors", "abductors", "calves",
        ])
    }

    @Test func theDisplayNamesFollowListOrder() {
        #expect(MuscleGroup.allCases.map(\.name) == [
            "Upper Chest", "Lower Chest",
            "Front Delts", "Side Delts", "Rear Delts", "Rotator Cuff",
            "Lats", "Upper Back", "Traps", "Lower Back",
            "Biceps", "Brachialis", "Triceps", "Forearms",
            "Abs", "Obliques",
            "Quads", "Hamstrings", "Glutes", "Adductors", "Abductors", "Calves",
        ])
    }

    @Test func eachBodyAreaHoldsItsMuscleGroupsInListOrder() {
        #expect(BodyArea.allCases.map(\.name) == ["Chest", "Shoulders", "Back", "Arms", "Core", "Legs"])
        #expect(BodyArea.chest.muscleGroups == [.upperChest, .lowerChest])
        #expect(BodyArea.shoulders.muscleGroups == [.frontDelts, .sideDelts, .rearDelts, .rotatorCuff])
        #expect(BodyArea.back.muscleGroups == [.lats, .upperBack, .traps, .lowerBack])
        #expect(BodyArea.arms.muscleGroups == [.biceps, .brachialis, .triceps, .forearms])
        #expect(BodyArea.core.muscleGroups == [.abs, .obliques])
        #expect(BodyArea.legs.muscleGroups == [.quads, .hamstrings, .glutes, .adductors, .abductors, .calves])
    }
}
