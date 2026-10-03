import SwiftUI

/// One body figure with each Muscle Group's regions filled in its Training Volume band's colour.
struct MuscleFigureView: View {
    let figure: MuscleFigure
    let volume: TrainingVolume

    private static let silhouette = Color(red: 0x14 / 255, green: 0x15 / 255, blue: 0x18 / 255)
    private static let silhouetteLine = Color(red: 0x3A / 255, green: 0x3E / 255, blue: 0x46 / 255)
    private static let neutralPart = Color(red: 0x20 / 255, green: 0x22 / 255, blue: 0x27 / 255)

    var body: some View {
        Canvas { context, size in
            let scale = size.width / figure.frame.width
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -figure.frame.minX, y: -figure.frame.minY)
            context.fill(figure.outline, with: .color(Self.silhouette))
            context.stroke(figure.outline, with: .color(Self.silhouetteLine), lineWidth: 1 / scale)
            for region in figure.regions {
                let fill = region.muscleGroup.map { volume.band($0).color } ?? Self.neutralPart
                context.fill(region.path, with: .color(fill))
                // A thin line in the silhouette's colour keeps neighbouring regions apart.
                context.stroke(region.path, with: .color(Self.silhouette), lineWidth: 1 / scale)
            }
        }
        .aspectRatio(figure.frame.size, contentMode: .fit)
    }
}
