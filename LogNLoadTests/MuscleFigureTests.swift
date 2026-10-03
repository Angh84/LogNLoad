import SwiftUI
import Testing
@testable import LogNLoad

/// The body figure (#60): the Muscle Group at a point. The known points come from the prototype's region check, so they
/// also prove the artwork's paths, packed arc flags included, parse into the shapes a browser draws.
struct MuscleFigureTests {
    @Test func everyArtworkPathParses() {
        let paths = [BodyArtwork.frontOutline, BodyArtwork.backOutline] + (BodyArtwork.front + BodyArtwork.back).map(\.d)
        for d in paths {
            #expect(throws: Never.self) { try SVGPath.path(d) }
        }
    }

    @Test func everyMuscleGroupHasARegion() {
        let drawn = Set((MuscleFigure.front.regions + MuscleFigure.back.regions).compactMap(\.muscleGroup))
        #expect(drawn == Set(MuscleGroup.allCases))
    }

    /// One point well inside each Muscle Group's region on each side, as the viewer sees it.
    @Test(arguments: [
        (MuscleFigure.Facing.front, 290, 342, MuscleGroup.upperChest), (.front, 434, 342, .upperChest),
        (.front, 307, 401, .lowerChest), (.front, 413, 401, .lowerChest),
        (.front, 247, 319, .frontDelts), (.front, 478, 319, .frontDelts),
        (.front, 209, 350, .sideDelts), (.front, 516, 342, .sideDelts),
        (.back, 925, 347, .sideDelts), (.back, 1242, 347, .sideDelts),
        (.back, 951, 329, .rearDelts), (.back, 1211, 325, .rearDelts),
        (.back, 992, 354, .rotatorCuff), (.back, 1175, 354, .rotatorCuff),
        (.back, 1023, 470, .lats), (.back, 1144, 470, .lats),
        (.back, 1054, 378, .upperBack), (.back, 1113, 378, .upperBack),
        (.back, 1038, 327, .traps), (.back, 1113, 327, .traps), (.front, 311, 301, .traps), (.front, 414, 299, .traps),
        (.back, 1061, 277, .traps), (.back, 1106, 277, .traps),
        (.back, 1049, 588, .lowerBack), (.back, 1118, 595, .lowerBack),
        (.front, 206, 435, .biceps), (.front, 521, 432, .biceps),
        (.front, 190, 468, .brachialis), (.front, 536, 478, .brachialis),
        (.front, 218, 487, .triceps), (.back, 933, 420, .triceps), (.back, 1229, 414, .triceps),
        (.front, 164, 545, .forearms), (.back, 876, 624, .forearms), (.back, 1287, 598, .forearms),
        (.front, 328, 464, .abs), (.front, 391, 458, .abs),
        (.front, 285, 596, .obliques), (.front, 442, 613, .obliques),
        (.front, 271, 768, .quads), (.front, 449, 802, .quads),
        (.back, 1003, 800, .hamstrings), (.back, 1162, 800, .hamstrings),
        (.back, 1016, 701, .glutes), (.back, 1130, 689, .glutes),
        (.front, 313, 702, .adductors), (.back, 1107, 797, .adductors),
        (.back, 1003, 637, .abductors), (.back, 1153, 631, .abductors),
        (.front, 307, 1079, .calves), (.back, 1141, 1107, .calves),
    ])
    func aPointLandsOnItsMuscleGroup(facing: MuscleFigure.Facing, x: Double, y: Double, muscleGroup: MuscleGroup) {
        #expect(MuscleFigure(facing).muscleGroup(at: CGPoint(x: x, y: y)) == muscleGroup)
    }

    @Test(arguments: [
        (MuscleFigure.Facing.front, 287, 972), // knee
        (.front, 119, 725), // hand
        (.front, 10, 10), (.back, 734, 10), // outside the body
    ])
    func aNeutralPartOrOutsideTheBodyIsNoMuscleGroup(facing: MuscleFigure.Facing, x: Double, y: Double) {
        #expect(MuscleFigure(facing).muscleGroup(at: CGPoint(x: x, y: y)) == nil)
    }
}
