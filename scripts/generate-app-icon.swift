import AppKit
import Foundation

NSApplication.shared.setActivationPolicy(.prohibited)

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = rootURL.appendingPathComponent("Resources", isDirectory: true)
let iconsetURL = rootURL.appendingPathComponent("Resources/AppIcon.iconset", isDirectory: true)
let iconURL = resourcesURL.appendingPathComponent("AppIcon.icns", isDirectory: false)
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

struct IconVariant {
  let name: String
  let pixels: Int
}

let variants = [
  IconVariant(name: "icon_16x16.png", pixels: 16),
  IconVariant(name: "icon_16x16@2x.png", pixels: 32),
  IconVariant(name: "icon_32x32.png", pixels: 32),
  IconVariant(name: "icon_32x32@2x.png", pixels: 64),
  IconVariant(name: "icon_128x128.png", pixels: 128),
  IconVariant(name: "icon_128x128@2x.png", pixels: 256),
  IconVariant(name: "icon_256x256.png", pixels: 256),
  IconVariant(name: "icon_256x256@2x.png", pixels: 512),
  IconVariant(name: "icon_512x512.png", pixels: 512),
  IconVariant(name: "icon_512x512@2x.png", pixels: 1024),
]

for variant in variants {
  let image = drawIcon(size: CGFloat(variant.pixels))
  try writePNG(image, to: iconsetURL.appendingPathComponent(variant.name))
}

let chunks: [(type: String, pixels: Int)] = [
  ("ic04", 16),
  ("ic11", 32),
  ("ic07", 128),
  ("ic13", 256),
]

let body = try chunks.reduce(into: Data()) { data, chunk in
  let image = drawIcon(size: CGFloat(chunk.pixels))
  guard let png = pngData(from: image) else {
    throw NSError(domain: "PinShotIcon", code: 2)
  }
  data.appendFourCC(chunk.type)
  data.appendUInt32BE(UInt32(png.count + 8))
  data.append(png)
}

var icns = Data()
icns.appendFourCC("icns")
icns.appendUInt32BE(UInt32(body.count + 8))
icns.append(body)
try icns.write(to: iconURL, options: .atomic)

func drawIcon(size: CGFloat) -> NSImage {
  let image = NSImage(size: NSSize(width: size, height: size))
  image.lockFocus()

  let bounds = NSRect(x: 0, y: 0, width: size, height: size)
  NSColor.clear.setFill()
  bounds.fill()

  let tile = bounds.insetBy(dx: size * 0.055, dy: size * 0.055)
  let radius = size * 0.215
  let tilePath = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)

  if let context = NSGraphicsContext.current?.cgContext,
     let gradient = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(),
      colors: [
        NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.19, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.13, green: 0.21, blue: 0.31, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.16, alpha: 1).cgColor,
      ] as CFArray,
      locations: [0, 0.55, 1]
     ) {
    context.saveGState()
    context.addPath(CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.clip()
    context.drawLinearGradient(
      gradient,
      start: CGPoint(x: tile.minX, y: tile.maxY),
      end: CGPoint(x: tile.maxX, y: tile.minY),
      options: []
    )
    context.restoreGState()
  }

  let shadow = NSShadow()
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
  shadow.shadowBlurRadius = size * 0.045
  shadow.shadowOffset = NSSize(width: 0, height: -size * 0.018)
  NSGraphicsContext.saveGraphicsState()
  shadow.set()
  NSColor.black.withAlphaComponent(0.12).setFill()
  tilePath.fill()
  NSGraphicsContext.restoreGraphicsState()

  let selection = NSRect(
    x: size * 0.245,
    y: size * 0.295,
    width: size * 0.51,
    height: size * 0.41
  )
  let selectionPath = NSBezierPath(roundedRect: selection, xRadius: size * 0.045, yRadius: size * 0.045)

  NSGraphicsContext.saveGraphicsState()
  let glow = NSShadow()
  glow.shadowColor = NSColor(calibratedRed: 0.45, green: 0.83, blue: 1.0, alpha: 0.72)
  glow.shadowBlurRadius = size * 0.035
  glow.shadowOffset = .zero
  glow.set()
  NSColor(calibratedRed: 0.55, green: 0.86, blue: 1.0, alpha: 0.95).setStroke()
  selectionPath.lineWidth = max(2, size * 0.024)
  selectionPath.stroke()
  NSGraphicsContext.restoreGraphicsState()

  drawCorner(at: NSPoint(x: selection.minX, y: selection.maxY), horizontal: 1, vertical: -1, size: size)
  drawCorner(at: NSPoint(x: selection.maxX, y: selection.maxY), horizontal: -1, vertical: -1, size: size)
  drawCorner(at: NSPoint(x: selection.minX, y: selection.minY), horizontal: 1, vertical: 1, size: size)
  drawCorner(at: NSPoint(x: selection.maxX, y: selection.minY), horizontal: -1, vertical: 1, size: size)

  let scanLine = NSBezierPath()
  scanLine.move(to: NSPoint(x: selection.minX + size * 0.07, y: selection.midY))
  scanLine.line(to: NSPoint(x: selection.maxX - size * 0.07, y: selection.midY))
  NSColor.white.withAlphaComponent(0.34).setStroke()
  scanLine.lineWidth = max(1, size * 0.012)
  scanLine.stroke()

  let pinCenter = NSPoint(x: size * 0.70, y: size * 0.26)
  let pinPath = NSBezierPath(ovalIn: NSRect(x: pinCenter.x - size * 0.055, y: pinCenter.y - size * 0.055, width: size * 0.11, height: size * 0.11))
  NSColor(calibratedRed: 0.95, green: 0.60, blue: 0.45, alpha: 1).setFill()
  pinPath.fill()

  let stem = NSBezierPath()
  stem.move(to: pinCenter)
  stem.line(to: NSPoint(x: pinCenter.x + size * 0.07, y: pinCenter.y - size * 0.09))
  NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.66, alpha: 0.9).setStroke()
  stem.lineWidth = max(1.2, size * 0.014)
  stem.stroke()

  image.unlockFocus()
  return image
}

func drawCorner(at point: NSPoint, horizontal: CGFloat, vertical: CGFloat, size: CGFloat) {
  let path = NSBezierPath()
  let length = size * 0.09
  path.move(to: point)
  path.line(to: NSPoint(x: point.x + horizontal * length, y: point.y))
  path.move(to: point)
  path.line(to: NSPoint(x: point.x, y: point.y + vertical * length))
  NSColor.white.withAlphaComponent(0.92).setStroke()
  path.lineCapStyle = .round
  path.lineWidth = max(2, size * 0.018)
  path.stroke()
}

func writePNG(_ image: NSImage, to url: URL) throws {
  guard let data = pngData(from: image) else {
    throw NSError(domain: "PinShotIcon", code: 1)
  }
  try data.write(to: url, options: .atomic)
}

func pngData(from image: NSImage) -> Data? {
  guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff)
  else {
    return nil
  }
  return bitmap.representation(using: .png, properties: [:])
}

extension Data {
  mutating func appendFourCC(_ value: String) {
    let bytes = Array(value.utf8)
    precondition(bytes.count == 4)
    append(contentsOf: bytes)
  }

  mutating func appendUInt32BE(_ value: UInt32) {
    append(UInt8((value >> 24) & 0xff))
    append(UInt8((value >> 16) & 0xff))
    append(UInt8((value >> 8) & 0xff))
    append(UInt8(value & 0xff))
  }
}
