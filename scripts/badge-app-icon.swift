#!/usr/bin/swift
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 2 else {
    fputs("Usage: badge-app-icon.swift <input.png> [output.png]\n", stderr)
    exit(1)
}

let inputPath = args[1]
let outputPath = args.count > 2 ? args[2] : args[1]

guard let source = NSImage(contentsOfFile: inputPath) else {
    fputs("Failed to load image: \(inputPath)\n", stderr)
    exit(1)
}

let size = source.size
let width = Int(size.width)
let height = Int(size.height)
guard width > 0, height > 0 else { exit(1) }

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else { exit(1) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
source.draw(in: NSRect(x: 0, y: 0, width: size.width, height: size.height))

let minSide = min(size.width, size.height)
let fontSize = minSide * 0.36
let margin = minSide * 0.06
let plus = "+" as NSString
let font = NSFont.systemFont(ofSize: fontSize, weight: .heavy)

// White outline for contrast on dark icon areas
let outlineAttrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white,
    .strokeColor: NSColor.white,
    .strokeWidth: -minSide * 0.018
]
let fillAttrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(calibratedRed: 0.92, green: 0.15, blue: 0.18, alpha: 1)
]

let textSize = plus.size(withAttributes: fillAttrs)
let textRect = NSRect(
    x: size.width - textSize.width - margin,
    y: margin,
    width: textSize.width,
    height: textSize.height
)
plus.draw(in: textRect, withAttributes: outlineAttrs)
plus.draw(in: textRect, withAttributes: fillAttrs)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
do {
    try png.write(to: URL(fileURLWithPath: outputPath))
    print("Wrote \(outputPath)")
} catch {
    fputs("Write failed: \(error)\n", stderr)
    exit(1)
}
