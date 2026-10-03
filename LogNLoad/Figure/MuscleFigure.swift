import SwiftUI

/// The front or back body figure as Muscle Group regions (#60), in the artwork's coordinates.
struct MuscleFigure {
    enum Facing {
        case front, back

        var name: String {
            switch self {
            case .front: "Front"
            case .back: "Back"
            }
        }
    }

    struct Region {
        /// None for a body part no Muscle Group covers, like a knee or a hand.
        let muscleGroup: MuscleGroup?
        let path: Path
    }

    let facing: Facing
    /// The part of the artwork that is drawn: the body, without the empty margins.
    let frame: CGRect
    let outline: Path
    /// In drawing order: the neutral parts, then the Muscle Groups.
    let regions: [Region]

    static let front = MuscleFigure(.front)
    static let back = MuscleFigure(.back)

    init(_ facing: Facing) {
        let (x, outline, shapes) = switch facing {
        case .front: (30.0, BodyArtwork.frontOutline, BodyArtwork.front)
        case .back: (754.0, BodyArtwork.backOutline, BodyArtwork.back)
        }
        self.facing = facing
        frame = CGRect(x: x, y: 150, width: 664, height: 1215)
        self.outline = Self.parse(outline)
        let regions = shapes.flatMap { Self.regions(of: $0, facing: facing) }
        self.regions = regions.filter { $0.muscleGroup == nil } + regions.filter { $0.muscleGroup != nil }
    }

    /// The topmost region's Muscle Group at `point`, as drawn.
    func muscleGroup(at point: CGPoint) -> MuscleGroup? {
        regions.last { $0.path.contains(point) }?.muscleGroup
    }

    /// The artwork is fixed and every path in it is tested to parse.
    private static func parse(_ d: String) -> Path {
        do {
            return try SVGPath.path(d)
        } catch {
            fatalError("Could not parse the body artwork: \(error)")
        }
    }

    private static func regions(of shape: BodyArtwork.Shape, facing: Facing) -> [Region] {
        let path = parse(shape.d)
        switch mapping(of: shape, facing: facing) {
        case .muscleGroup(let muscleGroup):
            return [Region(muscleGroup: muscleGroup, path: path)]
        case .cut(let halves):
            let bounds = path.boundingRect
            return halves.map { muscleGroup, polygon in
                let points = polygon.map { x, y in
                    // Polygons are drawn for the viewer's left side; the right side mirrors them.
                    let u = shape.side == .right ? 1 - x : x
                    return CGPoint(x: bounds.minX + u * bounds.width, y: bounds.minY + y * bounds.height)
                }
                return Region(muscleGroup: muscleGroup, path: path.intersection(Path { $0.addLines(points) }))
            }
        case .neutral:
            return [Region(muscleGroup: nil, path: path)]
        }
    }

    private enum Mapping {
        case muscleGroup(MuscleGroup)
        /// The shape split along straight lines: polygons in its bounding box (0...1), outer (lateral) at x = 0.
        case cut([(MuscleGroup, [(Double, Double)])])
        case neutral
    }

    /// The artwork's slugs as Muscle Groups (#60, from the prototype).
    private static func mapping(of shape: BodyArtwork.Shape, facing: Facing) -> Mapping {
        switch shape.slug {
        case "chest":
            .cut([
                (.upperChest, [(-0.1, -0.1), (1.1, -0.1), (1.1, 0.36), (-0.1, 0.42)]),
                (.lowerChest, [(-0.1, 0.42), (1.1, 0.36), (1.1, 1.1), (-0.1, 1.1)]),
            ])
        case "deltoids" where facing == .front:
            .cut([
                (.sideDelts, [(-0.1, -0.1), (0.48, -0.1), (0.25, 1.1), (-0.1, 1.1)]),
                (.frontDelts, [(0.48, -0.1), (1.1, -0.1), (1.1, 1.1), (0.25, 1.1)]),
            ])
        case "deltoids":
            .cut([
                (.sideDelts, [(-0.1, -0.1), (0.42, -0.1), (0.2, 1.1), (-0.1, 1.1)]),
                (.rearDelts, [(0.42, -0.1), (1.1, -0.1), (1.1, 1.1), (0.2, 1.1)]),
            ])
        case "trapezius" where facing == .front:
            .muscleGroup(.traps)
        case "trapezius":
            .cut([
                (.traps, [(-0.1, -0.1), (1.1, -0.1), (1.1, 0.3), (-0.1, 0.3)]),
                (.upperBack, [(-0.1, 0.3), (1.1, 0.3), (1.1, 1.1), (-0.1, 1.1)]),
            ])
        case "biceps":
            .cut([
                (.brachialis, [(-0.1, 0.5), (0.3, 0.5), (0.6, 1.1), (-0.1, 1.1)]),
                (.biceps, [(-0.1, -0.1), (1.1, -0.1), (1.1, 1.1), (0.6, 1.1), (0.3, 0.5), (-0.1, 0.5)]),
            ])
        // The upper trapezius runs up the back of the neck.
        case "neck" where facing == .back: .muscleGroup(.traps)
        // The large shape is the lats (index 1 on the left, 2 on the right); the shoulder-blade patches are the rotator cuff.
        case "upper-back": .muscleGroup((shape.side == .left ? shape.index == 1 : shape.index == 2) ? .lats : .rotatorCuff)
        // The upper gluteal shape is the gluteus medius.
        case "gluteal": .muscleGroup(shape.index == 0 ? .abductors : .glutes)
        case "obliques": .muscleGroup(.obliques)
        case "abs": .muscleGroup(.abs)
        case "triceps": .muscleGroup(.triceps)
        case "adductors": .muscleGroup(.adductors)
        case "quadriceps": .muscleGroup(.quads)
        case "calves": .muscleGroup(.calves)
        case "forearm": .muscleGroup(.forearms)
        case "lower-back": .muscleGroup(.lowerBack)
        case "hamstring": .muscleGroup(.hamstrings)
        default: .neutral
        }
    }
}
