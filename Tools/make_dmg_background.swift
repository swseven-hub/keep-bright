import AppKit

let outputPath = CommandLine.arguments.dropFirst().first ?? "build/dmg-background.png"
let size = NSSize(width: 560, height: 360)
let image = NSImage(size: size)

image.lockFocus()

NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
    .foregroundColor: NSColor.labelColor
]
let bodyAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14, weight: .regular),
    .foregroundColor: NSColor.secondaryLabelColor
]
let arrowAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 48, weight: .regular),
    .foregroundColor: NSColor.systemBlue
]

"Keep Bright".draw(at: NSPoint(x: 34, y: 298), withAttributes: titleAttributes)
"拖动到 Applications 完成安装".draw(at: NSPoint(x: 34, y: 270), withAttributes: bodyAttributes)
"→".draw(at: NSPoint(x: 258, y: 148), withAttributes: arrowAttributes)

let footerAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
    .foregroundColor: NSColor.tertiaryLabelColor
]
"菜单栏里的保持亮屏工具".draw(at: NSPoint(x: 34, y: 32), withAttributes: footerAttributes)

image.unlockFocus()

guard let data = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: data),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "KeepBrightDMGBackground", code: 1)
}

try FileManager.default.createDirectory(
    at: URL(fileURLWithPath: outputPath).deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: URL(fileURLWithPath: outputPath))
