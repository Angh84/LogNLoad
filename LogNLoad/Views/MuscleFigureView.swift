import SwiftUI

/// One body figure with each Muscle Group's regions filled in its Training Volume band's colour, and the selected
/// Muscle Group outlined. A tap reports the Muscle Group under it, or none.
struct MuscleFigureView: View {
    let figure: MuscleFigure
    let volume: TrainingVolume
    let selected: MuscleGroup?
    let onTap: (MuscleGroup?) -> Void

    private static let silhouette = Color(red: 0x14 / 255, green: 0x15 / 255, blue: 0x18 / 255)
    private static let silhouetteLine = Color(red: 0x3A / 255, green: 0x3E / 255, blue: 0x46 / 255)
    private static let neutralPart = Color(red: 0x20 / 255, green: 0x22 / 255, blue: 0x27 / 255)

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / figure.frame.width
            // Artwork coordinates to the view's: drawing applies it, a tap is mapped back through its inverse.
            let toView = CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: -figure.frame.minX, y: -figure.frame.minY)
            Canvas { context, _ in
                context.concatenate(toView)
                context.fill(figure.outline, with: .color(Self.silhouette))
                context.stroke(figure.outline, with: .color(Self.silhouetteLine), lineWidth: 1 / scale)
                for region in figure.regions {
                    let fill = region.muscleGroup.map { volume.band($0).color } ?? Self.neutralPart
                    context.fill(region.path, with: .color(fill))
                    // A thin line in the silhouette's colour keeps neighbouring regions apart.
                    context.stroke(region.path, with: .color(Self.silhouette), lineWidth: 1 / scale)
                }
                for region in figure.regions where region.muscleGroup != nil && region.muscleGroup == selected {
                    context.stroke(region.path, with: .color(.white), lineWidth: 2 / scale)
                }
            }
            .onTapGesture { location in
                onTap(figure.muscleGroup(at: location.applying(toView.inverted())))
            }
        }
        .aspectRatio(figure.frame.size, contentMode: .fit)
    }
}
