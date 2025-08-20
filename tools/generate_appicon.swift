import AppKit
import Foundation

func drawIcon(size: Int, destinationURL: URL) throws {
    let dim = CGFloat(size)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "icon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmap rep"])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    defer { NSGraphicsContext.restoreGraphicsState() }

    // Background
    NSColor.black.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: dim, height: dim)).fill()

    // Four horizontal white lines centered
    let lineThickness = max(2.0, dim * 0.06)
    let lineLength = dim * 0.6
    let x = (dim - lineLength) / 2.0

    let totalLines = 4
    let verticalPadding = dim * 0.16
    let availableHeight = dim - verticalPadding * 2
    let spacing = (availableHeight - (CGFloat(totalLines) * lineThickness)) / CGFloat(totalLines - 1)

    NSColor.white.setFill()
    for i in 0..<totalLines {
        let y = verticalPadding + CGFloat(i) * (lineThickness + spacing)
        let rect = NSRect(x: x, y: y, width: lineLength, height: lineThickness)
        NSBezierPath(rect: rect).fill()
    }

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render PNG"])
    }
    try png.write(to: destinationURL)
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconDir = projectRoot.appendingPathComponent("Assets.xcassets/AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconDir, withIntermediateDirectories: true)

let sizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]
for s in sizes {
    let url = iconDir.appendingPathComponent("AppIcon-\(s).png")
    try drawIcon(size: s, destinationURL: url)
    fputs("wrote \(url.path)\n", stderr)
}

print("App icon images generated.")


