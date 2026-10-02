import Testing
import UIKit
@testable import LogNLoad

/// WCAG AA for the app accent color (docs/spec/README.md, Appearance).
struct AccentColorTests {
    static let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
    let accent: UIColor

    init() throws {
        accent = try #require(UIColor(named: "AccentColor", in: nil, compatibleWith: Self.darkTraits))
    }

    @Test func blackTextOnTheAccentMeetsAA() {
        #expect(contrast(.black, accent) >= 4.5)
    }

    @Test(arguments: [
        UIColor.systemBackground, .secondarySystemBackground, .tertiarySystemBackground,
        .systemGroupedBackground, .secondarySystemGroupedBackground, .tertiarySystemGroupedBackground,
    ])
    func theAccentOnADarkBackgroundMeetsAA(background: UIColor) {
        #expect(contrast(accent, background.resolvedColor(with: Self.darkTraits)) >= 4.5)
    }

    func contrast(_ first: UIColor, _ second: UIColor) -> Double {
        let (a, b) = (luminance(first), luminance(second))
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    func luminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        #expect(color.getRed(&red, green: &green, blue: &blue, alpha: nil), "\(color) has no RGB components")
        func linear(_ channel: CGFloat) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
