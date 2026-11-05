#!/usr/bin/env swift
// Renders the app icon: a tree drawn in monospaced characters on a blue
// squircle, in the manner of macOS Big Sur icons. The characters are turned
// into one outline so they can be filled with a gradient, given weight and
// lit like a solid glyph rather than typed text.
//
//   swift scripts/make-icon.swift out.png [--art art.txt] [--weight 0.06]
//                                 [--width 0.74] [--set AppIcon.appiconset]
import AppKit
import CoreText

let arguments = Array(CommandLine.arguments.dropFirst())
guard let output = arguments.first else {
    FileHandle.standardError.write(Data("usage: make-icon.swift out.png [--art file] [--weight n] [--width n] [--set appiconset]\n".utf8))
    exit(2)
}
func option(_ flag: String) -> String? {
    guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

let defaultArt = """
   .-^^^^^^^-.
 .^^^^^^^^^^^^^.
(^^^^^^^^^^^^^^^)
 `^^\\ \\ | / /^^'
     \\ \\|/ /
     /_)|(_\\
"""
let art = option("--art").flatMap { try? String(contentsOfFile: $0, encoding: .utf8) } ?? defaultArt
let lines = art.split(separator: "\n", omittingEmptySubsequences: false).map(String.init).drop { $0.isEmpty }.reversed().drop { $0.isEmpty }.reversed()
/// Extra stroke around the glyphs, as a share of the point size.
let weight = option("--weight").flatMap(Double.init) ?? 0.06
/// How much of the tile the art spans.
let widthShare = option("--width").flatMap(Double.init) ?? 0.74

let font = NSFont(name: "DiatypeCode-Bold", size: 100) ?? NSFont(name: "Diatype Code Bold", size: 100) ?? NSFont.monospacedSystemFont(ofSize: 100, weight: .bold)

/// One path for the whole picture, laid out line by line at the given size,
/// with its bounds, in a coordinate space with y up.
func artPath(pointSize: CGFloat) -> (CGPath, CGRect) {
    let scaled = CTFontCreateCopyWithAttributes(font, pointSize, nil, nil)
    let advance = CTFontGetAdvancesForGlyphs(scaled, .horizontal, [CTFontGetGlyphWithName(scaled, "M" as CFString)], nil, 1)
    let lineHeight = pointSize * 1.15
    let path = CGMutablePath()
    for (row, line) in lines.enumerated() {
        let y = -CGFloat(row) * lineHeight
        for (column, character) in line.enumerated() where character != " " {
            var glyph = CGGlyph()
            var unichar = Array(String(character).utf16)
            guard CTFontGetGlyphsForCharacters(scaled, &unichar, &glyph, 1), let outline = CTFontCreatePathForGlyph(scaled, glyph, nil) else { continue }
            var transform = CGAffineTransform(translationX: CGFloat(column) * advance, y: y)
            path.addPath(outline, transform: transform)
            _ = transform
        }
    }
    return (path, path.boundingBoxOfPath)
}

func render(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else { return image }
    let scale = size / 1024

    // Apple's icon grid: the squircle fills 824 of 1024 points.
    let inset = 100 * scale
    let rect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let tile = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.2237, yRadius: rect.height * 0.2237)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 24 * scale, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    NSColor(srgbRed: 0.16, green: 0.45, blue: 0.95, alpha: 1).setFill()
    tile.fill()
    context.restoreGState()

    // The blue: lighter at the top, deeper at the bottom, with a soft
    // highlight in the upper left like a lit surface.
    context.saveGState()
    tile.addClip()
    NSGradient(colors: [
        NSColor(srgbRed: 0.36, green: 0.66, blue: 1.00, alpha: 1),
        NSColor(srgbRed: 0.18, green: 0.50, blue: 0.98, alpha: 1),
        NSColor(srgbRed: 0.10, green: 0.38, blue: 0.90, alpha: 1),
    ])!.draw(in: rect, angle: -90)
    let glowCenter = CGPoint(x: rect.minX + rect.width * 0.3, y: rect.maxY - rect.height * 0.2)
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
        .draw(fromCenter: glowCenter, radius: 0, toCenter: glowCenter, radius: rect.width * 0.7, options: [])
    context.restoreGState()

    // The tree, sized to the tile, then centred on its own bounds.
    let (probe, probeBounds) = artPath(pointSize: 100)
    let fit = min(rect.width * widthShare / probeBounds.width, rect.height * 0.66 / probeBounds.height)
    let pointSize = 100 * fit
    let (path, bounds) = artPath(pointSize: pointSize)
    let origin = CGPoint(x: rect.midX - bounds.midX, y: rect.midY - bounds.midY - pointSize * 0.02)
    var move = CGAffineTransform(translationX: origin.x, y: origin.y)
    let glyphs = path.copy(using: &move)!
    let stroke = pointSize * weight

    // A dark lift under the glyph, so it sits on the blue rather than in it.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -pointSize * 0.07), blur: pointSize * 0.22, color: NSColor(srgbRed: 0.02, green: 0.12, blue: 0.45, alpha: 0.6).cgColor)
    context.addPath(glyphs)
    context.setFillColor(NSColor.white.cgColor)
    context.setStrokeColor(NSColor.white.cgColor)
    context.setLineWidth(stroke)
    context.setLineJoin(.round)
    context.setLineCap(.round)
    context.drawPath(using: .fillStroke)
    context.restoreGState()

    // The glyph itself, white at the top shading to a pale blue below, as a
    // soft solid rather than flat paint.
    context.saveGState()
    context.addPath(glyphs.copy(strokingWithWidth: stroke, lineCap: .round, lineJoin: .round, miterLimit: 10))
    context.addPath(glyphs)
    context.clip()
    let glyphBox = glyphs.boundingBoxOfPath.insetBy(dx: -stroke, dy: -stroke)
    NSGradient(colors: [NSColor.white, NSColor(srgbRed: 0.86, green: 0.93, blue: 1.0, alpha: 1)])!.draw(in: glyphBox, angle: -90)
    context.restoreGState()

    image.unlockFocus()
    return image
}

func write(_ image: NSImage, size: Int, to url: URL) throws {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

try write(render(size: 1024), size: 1024, to: URL(fileURLWithPath: output))

if let set = option("--set") {
    let url = URL(fileURLWithPath: set, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    var images: [[String: String]] = []
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let pixels = points * scale
            let name = "icon_\(points)x\(points)@\(scale)x.png"
            try write(render(size: CGFloat(pixels)), size: pixels, to: url.appendingPathComponent(name))
            images.append(["size": "\(points)x\(points)", "idiom": "mac", "filename": name, "scale": "\(scale)x"])
        }
    }
    let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
    let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url.appendingPathComponent("Contents.json"))
}
