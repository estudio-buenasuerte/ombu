import AppKit

// Renders the Ombú app icon: a white ó cut into raster lines with a soft
// glow on a near-black squircle. Writes 1024 masters plus a contact sheet;
// slice the chosen master with sips into both appiconsets.
// Usage: swiftc scripts/make-icon.swift -o /tmp/make-icon && /tmp/make-icon <out-dir>

let outDir = CommandLine.arguments[1]
try! FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let side: CGFloat = 1024
let inset: CGFloat = 100
let box = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)

func bitmap(_ s: CGFloat = side) -> NSBitmapImageRep {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(s), pixelsHigh: Int(s),
                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
}

func font(_ family: String, bold: Bool, size: CGFloat) -> NSFont {
    let fm = NSFontManager.shared
    if let f = fm.font(withFamily: family, traits: bold ? .boldFontMask : [], weight: bold ? 9 : 5, size: size) { return f }
    return NSFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
}

var tileTint: NSColor? = nil
func tile(_ draw: (CGContext) -> Void) -> NSBitmapImageRep {
    let rep = bitmap()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let squircle = NSBezierPath(roundedRect: box, xRadius: 186, yRadius: 186)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: NSColor(calibratedWhite: 0, alpha: 0.35).cgColor)
    NSColor.black.setFill(); squircle.fill()
    ctx.restoreGState()
    let top = tileTint.map { NSColor(calibratedWhite: 0.11, alpha: 1).blended(withFraction: 0.10, of: $0)! } ?? NSColor(calibratedWhite: 0.11, alpha: 1)
    let bottom = tileTint.map { NSColor(calibratedWhite: 0.02, alpha: 1).blended(withFraction: 0.08, of: $0)! } ?? NSColor(calibratedWhite: 0.02, alpha: 1)
    NSGradient(starting: top, ending: bottom)!.draw(in: squircle, angle: -90)
    ctx.saveGState(); squircle.addClip(); draw(ctx); ctx.restoreGState()
    NSColor(calibratedWhite: 1, alpha: 0.14).setStroke(); squircle.lineWidth = 4; squircle.stroke()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// A white-on-black mask of a shape, used for ASCII / dot sampling.
func mask(_ draw: () -> Void) -> NSBitmapImageRep {
    let rep = bitmap()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.black.setFill(); NSRect(x: 0, y: 0, width: side, height: side).fill()
    NSColor.white.set(); draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func coverage(_ m: NSBitmapImageRep, cell: NSRect) -> CGFloat {
    var sum: CGFloat = 0; var n: CGFloat = 0
    var y = cell.minY; while y < cell.maxY { var x = cell.minX; while x < cell.maxX {
        // Bitmap rows are top-down; our coordinates are bottom-up.
        if let c = m.colorAt(x: Int(x), y: Int(side - 1 - y)) { sum += c.redComponent; n += 1 }
        x += 4 }; y += 4 }
    return n == 0 ? 0 : sum / n
}

func treeMask() -> NSBitmapImageRep {
    mask {
        for (cx, cy, r) in [(512, 640, 200), (380, 600, 150), (644, 600, 150), (450, 700, 140), (574, 700, 140)] {
            NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)).fill()
        }
        let trunk = NSBezierPath()
        trunk.move(to: NSPoint(x: 470, y: 560)); trunk.line(to: NSPoint(x: 554, y: 560))
        trunk.curve(to: NSPoint(x: 640, y: 240), controlPoint1: NSPoint(x: 554, y: 420), controlPoint2: NSPoint(x: 600, y: 300))
        trunk.line(to: NSPoint(x: 384, y: 240))
        trunk.curve(to: NSPoint(x: 470, y: 560), controlPoint1: NSPoint(x: 424, y: 300), controlPoint2: NSPoint(x: 470, y: 420))
        trunk.close(); trunk.fill()
    }
}

func glyphMask(_ s: String, family: String, size: CGFloat, dy: CGFloat = 0) -> NSBitmapImageRep {
    mask {
        let f = font(family, bold: true, size: size)
        let a = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: NSColor.white])
        let line = CTLineCreateWithAttributedString(a)
        let ctx = NSGraphicsContext.current!.cgContext
        let b = CTLineGetImageBounds(line, ctx)
        ctx.saveGState()
        ctx.textPosition = CGPoint(x: (side - b.width) / 2 - b.minX, y: (side - b.height) / 2 - b.minY + dy)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}

var sheet: [NSBitmapImageRep] = []

// Flow's hero technique: coverage grid, 3x box blur for a halo, faint dot field
// in the empty cells, ramp characters inside the mark.
func flowTile(_ m: NSBitmapImageRep, cols: Int, seed: Int = 1, halo: CGFloat = 0.6, ramp rampS: String = " .:-=+*#%@", dot: CGFloat = 0.07, jitter: CGFloat = 0.08, phosphor: NSColor? = nil, glow: CGFloat = 14, scan: CGFloat = 0.28) -> NSBitmapImageRep {
    let area = side - 2 * inset - 60
    let cw = area / CGFloat(cols)
    let ch = cw * 1.6
    let rows = Int(area / ch)
    let oy = inset + 30 + (area - CGFloat(rows) * ch) / 2
    let ox = inset + 30
    var cov = [CGFloat](repeating: 0, count: cols * rows)
    for r in 0..<rows { for c in 0..<cols {
        cov[r * cols + c] = coverage(m, cell: NSRect(x: ox + CGFloat(c) * cw, y: oy + CGFloat(r) * ch, width: cw, height: ch))
    } }
    var blur = cov
    for _ in 0..<3 {
        var out = blur
        for r in 0..<rows { for c in 0..<cols {
            var s: CGFloat = 0; var n: CGFloat = 0
            for dr in -1...1 { for dc in -1...1 {
                let rr = r + dr, cc = c + dc
                if rr >= 0, rr < rows, cc >= 0, cc < cols { s += blur[rr * cols + cc]; n += 1 }
            } }
            out[r * cols + c] = s / n
        } }
        blur = out
    }
    let ramp = Array(rampS)
    let f = font("ABC Diatype Mono", bold: false, size: cw / 0.6 * 0.92)
    var rng = UInt64(seed)
    func rnd() -> CGFloat { rng = rng &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((rng >> 33) % 1000) / 1000 }
    return tile { ctx in
        let ink = phosphor ?? NSColor.white
        if phosphor != nil {
            ctx.setShadow(offset: .zero, blur: glow, color: ink.withAlphaComponent(0.95).cgColor)
        }
        for r in 0..<rows { for c in 0..<cols {
            let i = r * cols + c
            let lum = max(cov[i], blur[i] * halo)
            let s = lum > 0.02 ? min(1, lum) : 0
            let ch_: Character; let alpha: CGFloat
            if s < 0.05 { ch_ = "."; alpha = dot + jitter * rnd() }
            else { let n = ramp.count - 1; ch_ = ramp[min(n, 1 + Int(s * CGFloat(n)))]; alpha = min(1, 0.14 + 0.78 * s) }
            let a = NSAttributedString(string: String(ch_), attributes: [.font: f, .foregroundColor: ink.withAlphaComponent(alpha)])
            let sz = a.size()
            a.draw(at: NSPoint(x: ox + (CGFloat(c) + 0.5) * cw - sz.width / 2, y: oy + (CGFloat(r) + 0.5) * ch - sz.height / 2))
        } }
        if phosphor != nil {
            // Scanlines and a glass vignette.
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            NSColor(calibratedWhite: 0, alpha: scan).setFill()
            var y: CGFloat = inset; while y < side - inset { NSRect(x: inset, y: y, width: side - 2 * inset, height: 3).fill(); y += 7 }
            NSGradient(colorsAndLocations: (NSColor(calibratedWhite: 0, alpha: 0), 0), (NSColor(calibratedWhite: 0, alpha: 0), 0.55), (NSColor(calibratedWhite: 0, alpha: 0.5), 1))!
                .draw(fromCenter: NSPoint(x: 512, y: 512), radius: 0, toCenter: NSPoint(x: 512, y: 512), radius: 620, options: [])
        }
    }
}

func ringMask(outer: CGFloat, inner: CGFloat) -> NSBitmapImageRep {
    mask {
        let ring = NSBezierPath(ovalIn: NSRect(x: 512 - outer, y: 512 - outer, width: 2 * outer, height: 2 * outer))
        ring.append(NSBezierPath(ovalIn: NSRect(x: 512 - inner, y: 512 - inner, width: 2 * inner, height: 2 * inner)).reversed)
        ring.fill()
    }
}
// Bowl of the o centred on the tile, with a smaller hand-set accent above it.
func drawO(size: CGFloat, centerY: CGFloat, accentWidth: CGFloat, accentLen: CGFloat, gap: CGFloat, accentX: CGFloat) {
    let f = font("ABC Diatype", bold: true, size: size)
    let a = NSAttributedString(string: "o", attributes: [.font: f, .foregroundColor: NSColor.white])
    let line = CTLineCreateWithAttributedString(a)
    let ctx = NSGraphicsContext.current!.cgContext
    let b = CTLineGetImageBounds(line, ctx)
    ctx.saveGState()
    ctx.textPosition = CGPoint(x: (side - b.width) / 2 - b.minX, y: centerY - b.height / 2 - b.minY)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
    let top = centerY + b.height / 2
    let p = NSBezierPath(); p.lineCapStyle = .round; p.lineWidth = accentWidth
    let dx = accentLen * cos(CGFloat.pi * 55 / 180), dy = accentLen * sin(CGFloat.pi * 55 / 180)
    p.move(to: NSPoint(x: 512 + accentX, y: top + gap))
    p.line(to: NSPoint(x: 512 + accentX + dx, y: top + gap + dy))
    NSColor.white.setStroke(); p.stroke()
}
func oMask(size: CGFloat, centerY: CGFloat, accentWidth: CGFloat, accentLen: CGFloat, gap: CGFloat, accentX: CGFloat = 10) -> NSBitmapImageRep {
    mask { drawO(size: size, centerY: centerY, accentWidth: accentWidth, accentLen: accentLen, gap: gap, accentX: accentX) }
}

// Raster version: the solid letter cut into horizontal scanlines, like a CRT.
func rasterTile(period: CGFloat, duty: CGFloat, glow: CGFloat, alpha: CGFloat = 0.95, interlace: CGFloat = 0, curvature: CGFloat = 0) -> NSBitmapImageRep {
    let layer = bitmap()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: layer)
    let lctx = NSGraphicsContext.current!.cgContext
    drawO(size: 860, centerY: 430, accentWidth: 58, accentLen: 90, gap: 56, accentX: 14)
    var y: CGFloat = 0; var n = 0
    while y < side {
        lctx.clear(CGRect(x: 0, y: y, width: side, height: period * (1 - duty)))
        if interlace > 0, n % 2 == 1 {
            lctx.setBlendMode(.destinationOut)
            lctx.setFillColor(NSColor(calibratedWhite: 0, alpha: interlace).cgColor)
            lctx.fill(CGRect(x: 0, y: y + period * (1 - duty), width: side, height: period * duty))
            lctx.setBlendMode(.normal)
        }
        y += period; n += 1
    }
    NSGraphicsContext.restoreGraphicsState()
    let img = NSImage(size: NSSize(width: side, height: side)); img.addRepresentation(layer)
    return tile { ctx in
        if glow > 0 {
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: glow, color: NSColor(calibratedWhite: 1, alpha: 0.7).cgColor)
            img.draw(in: NSRect(x: 0, y: 0, width: side, height: side), from: .zero, operation: .sourceOver, fraction: alpha)
            ctx.restoreGState()
        } else {
            img.draw(in: NSRect(x: 0, y: 0, width: side, height: side), from: .zero, operation: .sourceOver, fraction: alpha)
        }
        if curvature > 0 {
            // A faint reflection along the top of the glass, bowed like a tube face.
            ctx.saveGState()
            NSBezierPath(ovalIn: NSRect(x: -260, y: 560, width: side + 520, height: 900)).addClip()
            NSGradient(starting: NSColor(calibratedWhite: 1, alpha: curvature), ending: NSColor(calibratedWhite: 1, alpha: 0))!
                .draw(in: NSRect(x: 0, y: 560, width: side, height: side - 560 - inset), angle: -90)
            ctx.restoreGState()
            // Darker toward the bottom corners, where the tube falls away.
            NSGradient(colorsAndLocations: (NSColor(calibratedWhite: 0, alpha: 0), 0), (NSColor(calibratedWhite: 0, alpha: 0), 0.6), (NSColor(calibratedWhite: 0, alpha: 0.35), 1))!
                .draw(fromCenter: NSPoint(x: 512, y: 560), radius: 0, toCenter: NSPoint(x: 512, y: 560), radius: 700, options: [])
        }
    }
}

// ASCII tile with TV scanlines laid over it.
func scanlined(_ rep: NSBitmapImageRep, period: CGFloat, strength: CGFloat) -> NSBitmapImageRep {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let squircle = NSBezierPath(roundedRect: box, xRadius: 186, yRadius: 186)
    squircle.addClip()
    NSColor(calibratedWhite: 0, alpha: strength).setFill()
    var y: CGFloat = 0
    while y < side { NSRect(x: 0, y: y, width: side, height: period * 0.45).fill(); y += period }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

sheet.append(rasterTile(period: 20, duty: 0.4, glow: 22))
sheet.append(rasterTile(period: 20, duty: 0.4, glow: 22, curvature: 0.09))
sheet.append(rasterTile(period: 20, duty: 0.4, glow: 22, curvature: 0.14))

// Write masters and a contact sheet at Dock-ish size (256 + 64).
let names = ["r20", "r20-curve-09", "r20-curve-14"]
for (i, rep) in sheet.enumerated() {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/ombu-\(names[i])-1024.png"))
}
let big: CGFloat = 256, small: CGFloat = 64, pad: CGFloat = 24
let sheetRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(CGFloat(sheet.count) * (big + pad) + pad), pixelsHigh: Int(big + small + pad * 3),
                                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: sheetRep)
NSColor(calibratedWhite: 0.93, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: sheetRep.pixelsWide, height: sheetRep.pixelsHigh).fill()
for (i, rep) in sheet.enumerated() {
    let img = NSImage(size: NSSize(width: side, height: side)); img.addRepresentation(rep)
    let x = pad + CGFloat(i) * (big + pad)
    img.draw(in: NSRect(x: x, y: small + pad * 2, width: big, height: big))
    img.draw(in: NSRect(x: x + (big - small) / 2, y: pad, width: small, height: small))
}
NSGraphicsContext.restoreGraphicsState()
try! sheetRep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/sheet.png"))
print("done")
