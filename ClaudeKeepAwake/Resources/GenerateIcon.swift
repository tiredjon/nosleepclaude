// Draws the app icon (night sky + glowing bolt) and writes an .iconset
// directory of PNGs at every size macOS expects. Run via
// `swift GenerateIcon.swift <output-dir>`; build.sh converts the result
// to AppIcon.icns with `iconutil`. No external assets — pure AppKit/Core
// Graphics drawing plus the system "bolt.fill" SF Symbol, so this stays
// fully offline and reproducible for anyone building from source.
import AppKit
import CoreGraphics

func hex(_ h: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        red: CGFloat((h >> 16) & 0xFF) / 255,
        green: CGFloat((h >> 8) & 0xFF) / 255,
        blue: CGFloat(h & 0xFF) / 255,
        alpha: alpha
    )
}

// Deterministic star field so re-runs are stable.
struct SplitMix64 {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func nextDouble() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.225 // macOS "squircle-ish" continuous-corner approximation
    let bgPath = NSBezierPath(roundedRect: NSRect(origin: .zero, size: NSSize(width: size, height: size)), xRadius: cornerRadius, yRadius: cornerRadius)
    bgPath.addClip()

    // Night-sky vertical gradient background.
    let gradient = NSGradient(colors: [
        hex(0x241A45),  // deep indigo, top
        hex(0x120B26),  // near-black violet
        hex(0x07040F)   // almost black, bottom
    ], atLocations: [0.0, 0.55, 1.0], colorSpace: .deviceRGB)
    gradient?.draw(in: rect, angle: -90)

    // Soft warm glow behind the bolt, evoking the still-lit screen.
    let glowCenter = CGPoint(x: size / 2, y: size * 0.52)
    if let glow = NSGradient(colors: [hex(0xD97757, alpha: 0.55), hex(0xD97757, alpha: 0.0)]) {
        glow.draw(fromCenter: glowCenter, radius: 0, toCenter: glowCenter, radius: size * 0.40, options: [])
    }

    // Scattered stars.
    var rng = SplitMix64(state: 0xC0FFEE ^ UInt64(size))
    let starCount = 26
    for _ in 0..<starCount {
        let x = rng.nextDouble() * size
        let yTop = rng.nextDouble() * size * 0.62 // keep stars mostly above the bolt
        let r = (0.4 + rng.nextDouble() * 1.1) * (size / 1024) * 3.2
        let alpha = 0.25 + rng.nextDouble() * 0.55
        ctx.setFillColor(hex(0xF5F0FF, alpha: CGFloat(alpha)).cgColor)
        let starRect = CGRect(x: x - r, y: size - yTop - r, width: r * 2, height: r * 2)
        ctx.fillEllipse(in: starRect)
    }

    // Center bolt glyph — same silhouette as the "active" menu bar icon.
    let symbolSize = size * 0.44
    if let symbol = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .heavy)
        let configured = symbol.withSymbolConfiguration(config) ?? symbol
        let tinted = NSImage(size: configured.size)
        tinted.lockFocus()
        hex(0xFFFFFF).set()
        let bounds = NSRect(origin: .zero, size: configured.size)
        configured.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1.0)
        bounds.fill(using: .sourceAtop)
        tinted.unlockFocus()

        let drawSize = tinted.size
        let origin = CGPoint(x: (size - drawSize.width) / 2, y: (size * 0.52) - drawSize.height / 2)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = hex(0xFFC988, alpha: 0.9)
        shadow.shadowBlurRadius = size * 0.05
        shadow.shadowOffset = .zero
        shadow.set()
        tinted.draw(in: CGRect(origin: origin, size: drawSize))
        NSGraphicsContext.restoreGraphicsState()
    }

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, size: CGFloat, to path: String) {
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG for size \(size)")
    }
    try! png.write(to: URL(fileURLWithPath: path))
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let iconsetDir = outDir + "/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(name: String, points: CGFloat, scale: CGFloat)] = [
    ("icon_16x16", 16, 1), ("icon_16x16@2x", 16, 2),
    ("icon_32x32", 32, 1), ("icon_32x32@2x", 32, 2),
    ("icon_128x128", 128, 1), ("icon_128x128@2x", 128, 2),
    ("icon_256x256", 256, 1), ("icon_256x256@2x", 256, 2),
    ("icon_512x512", 512, 1), ("icon_512x512@2x", 512, 2),
]

for entry in sizes {
    let pixelSize = entry.points * entry.scale
    let image = drawIcon(size: pixelSize)
    savePNG(image, size: pixelSize, to: "\(iconsetDir)/\(entry.name).png")
    print("wrote \(entry.name).png (\(Int(pixelSize))px)")
}

// Also drop a 1024 master for previewing/marketing use outside the .icns.
let master = drawIcon(size: 1024)
savePNG(master, size: 1024, to: "\(outDir)/icon_master_1024.png")
print("wrote icon_master_1024.png")
