import SwiftUI

/// Display type is New York (serif); body type is SF Pro Rounded. All styles scale with Dynamic Type.
extension Font {
    static let akHero = Font.system(.largeTitle, design: .serif, weight: .bold)
    static let akLargeTitle = Font.system(.largeTitle, design: .serif, weight: .semibold)
    static let akTitle = Font.system(.title, design: .serif, weight: .semibold)
    static let akTitle2 = Font.system(.title2, design: .serif, weight: .semibold)
    static let akTitle3 = Font.system(.title3, design: .serif, weight: .semibold)
    static let akVerse = Font.system(.title3, design: .serif, weight: .regular)
    static let akHeadline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let akBody = Font.system(.body, design: .rounded)
    static let akBodyMedium = Font.system(.body, design: .rounded, weight: .medium)
    static let akCallout = Font.system(.callout, design: .rounded)
    static let akSubheadline = Font.system(.subheadline, design: .rounded)
    static let akSubheadlineSemibold = Font.system(.subheadline, design: .rounded, weight: .semibold)
    static let akFootnote = Font.system(.footnote, design: .rounded)
    static let akCaption = Font.system(.caption, design: .rounded, weight: .medium)
    static let akOverline = Font.system(.caption, design: .rounded, weight: .bold)

    /// Big serif numbers (streaks, stats). Fixed base size scaled by the caller with @ScaledMetric.
    static func akNumber(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .serif)
    }
}

extension View {
    /// Small caps style label: "TODAY'S VERSE".
    func akOverline(color: Color = Theme.goldText) -> some View {
        self.font(.akOverline)
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
    static let page: CGFloat = 20
    static let section: CGFloat = 28
}
