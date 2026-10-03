import SwiftUI

/// Reads an SVG path's `d` attribute into a `Path`: M, L, H, V, C, S, Q, T, A and Z, absolute and relative.
enum SVGPath {
    struct ParseError: Error {}

    static func path(_ d: String) throws -> Path {
        var reader = Reader(bytes: Array(d.utf8))
        var path = Path()
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        // The previous command's last control point, which S and T reflect.
        var cubicControl: CGPoint?
        var quadControl: CGPoint?
        var command: UInt8?

        while reader.skipSeparators() {
            if let letter = reader.command() {
                // A path starts with a move.
                guard command != nil || letter | 0x20 == UInt8(ascii: "m") else { throw ParseError() }
                command = letter
            }
            guard let letter = command else { throw ParseError() }
            let isRelative = letter >= UInt8(ascii: "a")
            func point() throws -> CGPoint {
                let point = CGPoint(x: try reader.number(), y: try reader.number())
                return isRelative ? CGPoint(x: current.x + point.x, y: current.y + point.y) : point
            }
            var nextCubic: CGPoint?
            var nextQuad: CGPoint?

            switch letter | 0x20 {
            case UInt8(ascii: "m"):
                current = try point()
                subpathStart = current
                path.move(to: current)
                // Further pairs after a move are lines.
                command = isRelative ? UInt8(ascii: "l") : UInt8(ascii: "L")
            case UInt8(ascii: "l"):
                current = try point()
                path.addLine(to: current)
            case UInt8(ascii: "h"):
                let x = try reader.number()
                current.x = isRelative ? current.x + x : x
                path.addLine(to: current)
            case UInt8(ascii: "v"):
                let y = try reader.number()
                current.y = isRelative ? current.y + y : y
                path.addLine(to: current)
            case UInt8(ascii: "c"):
                let control1 = try point()
                let control2 = try point()
                current = try point()
                path.addCurve(to: current, control1: control1, control2: control2)
                nextCubic = control2
            case UInt8(ascii: "s"):
                let control1 = reflect(cubicControl, around: current)
                let control2 = try point()
                current = try point()
                path.addCurve(to: current, control1: control1, control2: control2)
                nextCubic = control2
            case UInt8(ascii: "q"):
                let control = try point()
                current = try point()
                path.addQuadCurve(to: current, control: control)
                nextQuad = control
            case UInt8(ascii: "t"):
                let control = reflect(quadControl, around: current)
                current = try point()
                path.addQuadCurve(to: current, control: control)
                nextQuad = control
            case UInt8(ascii: "a"):
                let radii = CGSize(width: try reader.number(), height: try reader.number())
                let rotation = try reader.number()
                let isLargeArc = try reader.flag()
                let sweeps = try reader.flag()
                let end = try point()
                addArc(to: &path, from: current, to: end, radii: radii, rotation: rotation, isLargeArc: isLargeArc, sweeps: sweeps)
                current = end
            case UInt8(ascii: "z"):
                path.closeSubpath()
                current = subpathStart
                command = nil
            default:
                throw ParseError()
            }
            cubicControl = nextCubic
            quadControl = nextQuad
        }
        return path
    }

    private static func reflect(_ control: CGPoint?, around point: CGPoint) -> CGPoint {
        guard let control else { return point }
        return CGPoint(x: 2 * point.x - control.x, y: 2 * point.y - control.y)
    }

    /// The SVG endpoint-to-centre conversion (SVG 1.1, appendix F.6.5), drawn as a unit-circle arc under a transform.
    private static func addArc(
        to path: inout Path, from start: CGPoint, to end: CGPoint, radii: CGSize, rotation: Double, isLargeArc: Bool, sweeps: Bool
    ) {
        guard start != end else { return }
        var rx = abs(radii.width), ry = abs(radii.height)
        guard rx > 0, ry > 0 else {
            path.addLine(to: end)
            return
        }
        let phi = rotation * .pi / 180
        let (cosPhi, sinPhi) = (cos(phi), sin(phi))
        let dx = (start.x - end.x) / 2, dy = (start.y - end.y) / 2
        let x1 = cosPhi * dx + sinPhi * dy
        let y1 = -sinPhi * dx + cosPhi * dy
        let lambda = x1 * x1 / (rx * rx) + y1 * y1 / (ry * ry)
        if lambda > 1 {
            rx *= lambda.squareRoot()
            ry *= lambda.squareRoot()
        }
        let numerator = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
        let coefficient = max(0, numerator / denominator).squareRoot() * (isLargeArc == sweeps ? -1 : 1)
        let cx1 = coefficient * rx * y1 / ry
        let cy1 = -coefficient * ry * x1 / rx
        let center = CGPoint(
            x: cosPhi * cx1 - sinPhi * cy1 + (start.x + end.x) / 2,
            y: sinPhi * cx1 + cosPhi * cy1 + (start.y + end.y) / 2
        )
        let from = CGVector(dx: (x1 - cx1) / rx, dy: (y1 - cy1) / ry)
        let to = CGVector(dx: (-x1 - cx1) / rx, dy: (-y1 - cy1) / ry)
        var delta = angle(from, to)
        if !sweeps, delta > 0 { delta -= 2 * .pi }
        if sweeps, delta < 0 { delta += 2 * .pi }
        let transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: phi).scaledBy(x: rx, y: ry)
        path.addRelativeArc(center: .zero, radius: 1, startAngle: .radians(angle(CGVector(dx: 1, dy: 0), from)), delta: .radians(delta), transform: transform)
    }

    private static func angle(_ u: CGVector, _ v: CGVector) -> Double {
        atan2(u.dx * v.dy - u.dy * v.dx, u.dx * v.dx + u.dy * v.dy)
    }

    private struct Reader {
        let bytes: [UInt8]
        var offset = 0

        /// Skips whitespace and commas; false at the end.
        mutating func skipSeparators() -> Bool {
            while offset < bytes.count, [UInt8(ascii: " "), UInt8(ascii: ","), 0x09, 0x0A, 0x0D].contains(bytes[offset]) {
                offset += 1
            }
            return offset < bytes.count
        }

        mutating func command() -> UInt8? {
            guard skipSeparators() else { return nil }
            let byte = bytes[offset] | 0x20
            guard byte >= UInt8(ascii: "a"), byte <= UInt8(ascii: "z") else { return nil }
            offset += 1
            return bytes[offset - 1]
        }

        /// A number such as "12", "-.5" or "1.71". A second "." starts the next number, as in "1.5.5".
        mutating func number() throws -> Double {
            _ = skipSeparators()
            let start = offset
            if offset < bytes.count, bytes[offset] == UInt8(ascii: "-") { offset += 1 }
            var sawDot = false
            while offset < bytes.count {
                let byte = bytes[offset]
                if byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") {
                    offset += 1
                } else if byte == UInt8(ascii: "."), !sawDot {
                    sawDot = true
                    offset += 1
                } else {
                    break
                }
            }
            guard let value = Double(String(decoding: bytes[start..<offset], as: UTF8.self)) else { throw ParseError() }
            return value
        }

        /// An arc flag: one character, so "012.89" is the flags 0 and 1, then 2.89.
        mutating func flag() throws -> Bool {
            _ = skipSeparators()
            guard offset < bytes.count, bytes[offset] == UInt8(ascii: "0") || bytes[offset] == UInt8(ascii: "1") else {
                throw ParseError()
            }
            offset += 1
            return bytes[offset - 1] == UInt8(ascii: "1")
        }
    }
}
