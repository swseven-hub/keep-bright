import AppKit

let outputDirectory = CommandLine.arguments.dropFirst().first ?? "build/AppIcon.iconset"
let fileManager = FileManager.default
try fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

struct IconTarget {
    let fileName: String
    let points: CGFloat
    let scale: CGFloat

    var pixels: Int {
        Int(points * scale)
    }
}

let targets = [
    IconTarget(fileName: "icon_16x16.png", points: 16, scale: 1),
    IconTarget(fileName: "icon_16x16@2x.png", points: 16, scale: 2),
    IconTarget(fileName: "icon_32x32.png", points: 32, scale: 1),
    IconTarget(fileName: "icon_32x32@2x.png", points: 32, scale: 2),
    IconTarget(fileName: "icon_128x128.png", points: 128, scale: 1),
    IconTarget(fileName: "icon_128x128@2x.png", points: 128, scale: 2),
    IconTarget(fileName: "icon_256x256.png", points: 256, scale: 1),
    IconTarget(fileName: "icon_256x256@2x.png", points: 256, scale: 2),
    IconTarget(fileName: "icon_512x512.png", points: 512, scale: 1),
    IconTarget(fileName: "icon_512x512@2x.png", points: 512, scale: 2)
]

for target in targets {
    let size = NSSize(width: target.pixels, height: target.pixels)
    let image = NSImage(size: size)
    image.lockFocus()

    let bounds = NSRect(origin: .zero, size: size)
    let radius = size.width * 0.215
    let background = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)
    NSColor(calibratedRed: 0.92, green: 0.94, blue: 0.91, alpha: 1).setFill()
    background.fill()

    let highlight = NSBezierPath(
        roundedRect: bounds.insetBy(dx: size.width * 0.08, dy: size.height * 0.08),
        xRadius: radius * 0.74,
        yRadius: radius * 0.74
    )
    NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 0.28).setFill()
    highlight.fill()

    let cupRect = NSRect(
        x: size.width * 0.25,
        y: size.height * 0.34,
        width: size.width * 0.42,
        height: size.height * 0.26
    )
    let cupBody = NSBezierPath(roundedRect: cupRect, xRadius: size.width * 0.06, yRadius: size.width * 0.06)
    NSColor.white.setFill()
    cupBody.fill()

    let handleRect = NSRect(
        x: cupRect.maxX - size.width * 0.03,
        y: cupRect.midY - size.height * 0.07,
        width: size.width * 0.16,
        height: size.height * 0.14
    )
    let handle = NSBezierPath(ovalIn: handleRect)
    handle.lineWidth = max(2, size.width * 0.035)
    NSColor.white.setStroke()
    handle.stroke()

    let saucerRect = NSRect(
        x: size.width * 0.22,
        y: size.height * 0.27,
        width: size.width * 0.54,
        height: size.height * 0.08
    )
    let saucer = NSBezierPath(ovalIn: saucerRect)
    NSColor.white.withAlphaComponent(0.86).setFill()
    saucer.fill()

    let sunCenter = NSPoint(x: size.width * 0.72, y: size.height * 0.69)
    let sunRadius = size.width * 0.085
    let sun = NSBezierPath(ovalIn: NSRect(
        x: sunCenter.x - sunRadius,
        y: sunCenter.y - sunRadius,
        width: sunRadius * 2,
        height: sunRadius * 2
    ))
    NSColor(calibratedRed: 1, green: 0.76, blue: 0.22, alpha: 1).setFill()
    sun.fill()

    image.unlockFocus()

    guard let data = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: data),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "KeepBrightIcon", code: 1)
    }

    let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent(target.fileName)
    try png.write(to: url)
}
