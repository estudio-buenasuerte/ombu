#!/usr/bin/env swift
// Renders the app icon: an ASCII tree on a blue squircle, in the manner of
// macOS Big Sur icons. Writes a 1024 px PNG, and with --set also the whole
// AppIcon.appiconset.
//
//   swift scripts/make-icon.swift out.png [--art art.txt] [--set Resources/Assets.xcassets/AppIcon.appiconset]
import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())
guard let output = arguments.first else {
    FileHandle.standardError.write(Data("usage: make-icon.swift out.png [--art file] [--set appiconset]\n".utf8))
    exit(2)
}
func option(_ flag: String) -> String? {
    guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

let defaultArt = """
    .~*~*~*~*~*~.
  .~*~*~*~*~*~*~*~.
 (~*~*~*~*~*~*~*~*~)
  `~*~\\ \\ | / /~*~'
       \\ \\|/ /
        \\ | /
        _)|(_
"""
let art = option("--art").flatMap { try? String(contentsOfFile: $0, encoding: .utf8) } ?? defaultArt
let lines = art.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

func render(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else { return image }
    let scale = size / 1024

    // Apple's icon grid: the squircle fills 824 of 1024 points.
    let inset = 100 * scale
    let rect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.2237, yRadius: rect.height * 0.2237)

    // Shadow under the tile, as the system draws for its own icons.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 24 * scale, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    NSColor(srgbRed: 0.16, green: 0.45, blue: 0.95, alpha: 1).setFill()
    path.fill()
    context.restoreGState()

    // The blue: lighter at the top, deeper at the bottom, with a soft
    // highlight in the upper left like a lit surface.
    context.saveGState()
    path.addClip()
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.36, green: 0.66, blue: 1.00, alpha: 1),
        NSColor(srgbRed: 0.18, green: 0.50, blue: 0.98, alpha: 1),
        NSColor(srgbRed: 0.10, green: 0.38, blue: 0.90, alpha: 1),
    ])!
    gradient.draw(in: rect, angle: -90)
    let glow = NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
    glow.draw(fromCenter: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.maxY - rect.height * 0.2), radius: 0,
              toCenter: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.maxY - rect.height * 0.2), radius: rect.width * 0.7, options: [])
    context.restoreGState()

    // The tree, in a monospaced face so the columns line up. Fitted to the
    // tile with equal margins, then drawn white with the soft lift Enso's
    // glyph has: a dark shadow below and a faint inner light above.
    let font = NSFont(name: "DiatypeCode-Bold", size: 100) ?? NSFont(name: "Diatype Code Bold", size: 100) ?? NSFont.monospacedSystemFont(ofSize: 100, weight: .bold)
    let columns = lines.map(\.count).max() ?? 1
    let advance = ("M" as NSString).size(withAttributes: [.font: font]).width
    let lineHeight: CGFloat = 100 * 1.08
    let target = rect.width * 0.78
    let pointSize = min(100 * target / (advance * CGFloat(columns)), 100 * (rect.height * 0.66) / (lineHeight * CGFloat(lines.count)))
    let scaled = NSFont(descriptor: font.fontDescriptor, size: pointSize) ?? font
    let style = NSMutableParagraphStyle()
    style.alignment = .left
    style.lineSpacing = pointSize * 0.08
    let attributes: [NSAttributedString.Key: Any] = [
        .font: scaled,
        .foregroundColor: NSColor.white,
        .paragraphStyle: style,
    ]
    let text = NSAttributedString(string: lines.joined(separator: "\n"), attributes: attributes)
    let textSize = text.size()
    let origin = CGPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2 - pointSize * 0.05)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -pointSize * 0.08), blur: pointSize * 0.22, color: NSColor(srgbRed: 0.02, green: 0.12, blue: 0.45, alpha: 0.55).cgColor)
    text.draw(at: origin)
    context.restoreGState()
    text.draw(at: origin)

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

let master = render(size: 1024)
try write(master, size: 1024, to: URL(fileURLWithPath: output))

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
