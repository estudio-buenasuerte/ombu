import AppKit

/// Colours and measurements for Ombú's own chrome: the frosted window, the
/// sidebar and the card the terminal sits in. The terminal itself keeps its
/// Ghostty theme, so the chrome follows the window's appearance instead,
/// which the terminal background decides.
enum Theme {
    /// Hairlines, borders and hover washes: white on a dark frost, near-black
    /// on a light one, at the given strength.
    static func ink(_ alpha: CGFloat = 1) -> NSColor {
        dynamic(dark: NSColor(white: 1, alpha: alpha), light: NSColor(white: 0.08, alpha: alpha))
    }

    /// Text at a given weight. Dark chrome keeps the airy white ramp; light
    /// chrome lifts the low and middle values, since dark ink needs more
    /// weight than light ink to read at the same nominal strength.
    static func text(_ alpha: CGFloat) -> NSColor {
        dynamic(dark: NSColor(white: 1, alpha: alpha), light: NSColor(white: 0.08, alpha: min(1, pow(alpha, 0.6))))
    }

    /// Laid over the frost so a bright desktop never washes the chrome out:
    /// the dark side deepens toward black, the light side lifts toward white.
    static let windowWash = dynamic(dark: NSColor(white: 0, alpha: 0.38), light: NSColor(white: 1, alpha: 0.10))

    /// The selected row's pill and the hovered row's wash.
    static let selection = ink(0.10)
    static let hover = ink(0.06)

    static let cardRadius: CGFloat = 10
    static let cardInset: CGFloat = 10
    static let cardBorder = ink(0.09)
    static let rowRadius: CGFloat = 7
    /// Rows keep this much from the sidebar's edges.
    static let rowInset: CGFloat = 10
    /// A tab row sits this much further in than its workspace row.
    static let tabIndent: CGFloat = 12
    static let sidebarWidth: CGFloat = 248

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
