import AppKit

/// Colours and measurements for Ombú's own chrome: the frosted window, the
/// sidebar and the card the terminal sits in. The terminal itself keeps its
/// Ghostty theme, so the chrome follows the window's appearance instead,
/// which the terminal background decides.
enum Theme {
    /// Text, hairlines and hover washes: white on a dark frost, near-black
    /// on a light one, at the given strength.
    static func ink(_ alpha: CGFloat = 1) -> NSColor {
        dynamic(dark: NSColor(white: 1, alpha: alpha), light: NSColor(white: 0.08, alpha: alpha))
    }

    /// Laid over the frost so a bright desktop never washes the chrome out:
    /// the dark side deepens toward black, the light side lifts toward white.
    static let windowWash = dynamic(dark: NSColor(white: 0, alpha: 0.38), light: NSColor(white: 1, alpha: 0.10))

    /// The selected row's pill.
    static let selection = dynamic(dark: NSColor.controlAccentColor.withAlphaComponent(0.26), light: NSColor.controlAccentColor.withAlphaComponent(0.20))

    static let cardRadius: CGFloat = 10
    static let cardInset: CGFloat = 10
    static let rowRadius: CGFloat = 7

    static func dynamic(dark: NSColor, light: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }
}

extension NSColor {
    /// The colour as the appearance draws it, for layers, which take no
    /// dynamic colours.
    func cgColor(in appearance: NSAppearance) -> CGColor {
        var color = cgColor
        appearance.performAsCurrentDrawingAppearance { color = cgColor }
        return color
    }
}
