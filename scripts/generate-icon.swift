import AppKit
import Foundation

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: generate-icon.swift <output-png-path>\n", stderr)
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let canvasSize: CGFloat = 1024
let rect = NSRect(x: 0, y: 0, width: canvasSize, height: canvasSize)

let image = NSImage(size: rect.size)
image.lockFocus()

let outerPath = NSBezierPath(roundedRect: rect.insetBy(dx: 24, dy: 24), xRadius: 220, yRadius: 220)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 1.00, green: 0.77, blue: 0.38, alpha: 1.0),
    NSColor(calibratedRed: 0.95, green: 0.46, blue: 0.28, alpha: 1.0)
])
gradient?.draw(in: outerPath, angle: -90)

NSColor(calibratedWhite: 1.0, alpha: 0.16).setStroke()
outerPath.lineWidth = 8
outerPath.stroke()

let boardRect = NSRect(x: 240, y: 186, width: 544, height: 660)
let boardPath = NSBezierPath(roundedRect: boardRect, xRadius: 80, yRadius: 80)
NSColor(calibratedWhite: 1.0, alpha: 0.94).setFill()
boardPath.fill()

NSColor(calibratedWhite: 0.1, alpha: 0.10).setStroke()
boardPath.lineWidth = 4
boardPath.stroke()

let clipRect = NSRect(x: 396, y: 726, width: 232, height: 132)
let clipPath = NSBezierPath(roundedRect: clipRect, xRadius: 56, yRadius: 56)
NSColor(calibratedWhite: 0.98, alpha: 1.0).setFill()
clipPath.fill()

let clipInnerRect = NSRect(x: 444, y: 758, width: 136, height: 68)
let clipInnerPath = NSBezierPath(roundedRect: clipInnerRect, xRadius: 30, yRadius: 30)
NSColor(calibratedRed: 0.96, green: 0.57, blue: 0.27, alpha: 1.0).setFill()
clipInnerPath.fill()

let pPath = NSBezierPath()
pPath.move(to: NSPoint(x: 360, y: 345))
pPath.line(to: NSPoint(x: 360, y: 675))
pPath.lineWidth = 58
pPath.lineCapStyle = .round
NSColor(calibratedRed: 0.96, green: 0.45, blue: 0.24, alpha: 1.0).setStroke()
pPath.stroke()

let pBowl = NSBezierPath(roundedRect: NSRect(x: 360, y: 505, width: 285, height: 170), xRadius: 85, yRadius: 85)
NSColor(calibratedRed: 0.96, green: 0.45, blue: 0.24, alpha: 1.0).setFill()
pBowl.fill()

let pCutout = NSBezierPath(roundedRect: NSRect(x: 425, y: 545, width: 150, height: 92), xRadius: 46, yRadius: 46)
NSColor(calibratedWhite: 1.0, alpha: 0.94).setFill()
pCutout.fill()

image.unlockFocus()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try pngData.write(to: outputURL, options: .atomic)

print("Wrote \(outputPath)")
