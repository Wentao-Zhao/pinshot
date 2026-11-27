import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = rootURL.appendingPathComponent("Resources", isDirectory: true)
let iconsetURL = resourcesURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let iconURL = resourcesURL.appendingPathComponent("AppIcon.icns")
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let variants: [(String, Int)] = [
  ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
  ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
  ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
  ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
  ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for (name, pixels) in variants {
  try iconBitmap(pixels: pixels).representation(using: .png, properties: [:])!
    .write(to: iconsetURL.appendingPathComponent(name), options: .atomic)
}
try iconBitmap(pixels: 1024).representation(using: .png, properties: [:])!
  .write(to: resourcesURL.appendingPathComponent("AppIcon.png"), options: .atomic)

// Use the system encoder for the full set of standard and Retina representations.
let encoder = Process()
encoder.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
encoder.arguments = ["--convert", "icns", "--output", iconURL.path, iconsetURL.path]
try encoder.run()
encoder.waitUntilExit()
guard encoder.terminationStatus == 0 else {
  throw NSError(domain: "PinShotIcon", code: Int(encoder.terminationStatus))
}

let previewURL = rootURL.appendingPathComponent("dist/icon-preview.png")
try FileManager.default.createDirectory(at: previewURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try previewBitmap().representation(using: .png, properties: [:])!.write(to: previewURL, options: .atomic)

func bitmap(width: Int, height: Int, draw: () -> Void) -> NSBitmapImageRep {
  let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  bitmap.size = NSSize(width: width, height: height)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  NSGraphicsContext.current?.imageInterpolation = .high
  NSGraphicsContext.current?.cgContext.clear(CGRect(x: 0, y: 0, width: width, height: height))
  draw()
  NSGraphicsContext.restoreGraphicsState()
  return bitmap
}

func iconBitmap(pixels: Int) -> NSBitmapImageRep {
  bitmap(width: pixels, height: pixels) {
    let scale = CGFloat(pixels) / 1024
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: scale, y: scale)
    let tileRect = NSRect(x: 88, y: 88, width: 848, height: 848)
    let tile = NSBezierPath(roundedRect: tileRect, xRadius: 190, yRadius: 190)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(srgbRed: 0.13, green: 0.17, blue: 0.24, alpha: 0.23)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.set()
    NSColor.white.setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()

    // The selected A design uses a quiet porcelain face and a cobalt capture mark.
    context.saveGState()
    context.addPath(CGPath(roundedRect: tileRect, cornerWidth: 190, cornerHeight: 190, transform: nil))
    context.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
      NSColor.white.cgColor,
      NSColor(srgbRed: 0.975, green: 0.979, blue: 0.989, alpha: 1).cgColor,
      NSColor(srgbRed: 0.951, green: 0.959, blue: 0.975, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 0.7, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 936),
                               end: CGPoint(x: 512, y: 88), options: [])
    context.restoreGState()
    NSColor(srgbRed: 0.78, green: 0.80, blue: 0.85, alpha: 0.65).setStroke()
    tile.lineWidth = pixels <= 32 ? 0.45 / scale : 1.4
    tile.stroke()

    let blue = NSColor(srgbRed: 0.02, green: 0.29, blue: 1, alpha: 1)
    blue.setFill()
    let upperLeft = captureCorner()
    upperLeft.fill()
    let lowerRight = captureCorner()
    let rotate = NSAffineTransform()
    rotate.translateX(by: 1040, yBy: 1024)
    rotate.scaleX(by: -1, yBy: -1)
    lowerRight.transform(using: rotate as AffineTransform)
    lowerRight.fill()

    // The captured square completes the open frame without adding a second symbol.
    let capturedPixel = NSBezierPath(roundedRect: NSRect(x: 638, y: 646, width: 116, height: 116),
                                     xRadius: 18, yRadius: 18)
    capturedPixel.fill()
  }
}

func captureCorner() -> NSBezierPath {
  let path = NSBezierPath()
  path.move(to: NSPoint(x: 286, y: 430))
  path.line(to: NSPoint(x: 286, y: 664))
  path.curve(to: NSPoint(x: 346, y: 724), controlPoint1: NSPoint(x: 286, y: 697),
             controlPoint2: NSPoint(x: 313, y: 724))
  path.line(to: NSPoint(x: 550, y: 724))
  path.curve(to: NSPoint(x: 566, y: 708), controlPoint1: NSPoint(x: 559, y: 724),
             controlPoint2: NSPoint(x: 566, y: 717))
  path.line(to: NSPoint(x: 566, y: 660))
  path.curve(to: NSPoint(x: 550, y: 644), controlPoint1: NSPoint(x: 566, y: 651),
             controlPoint2: NSPoint(x: 559, y: 644))
  path.line(to: NSPoint(x: 366, y: 644))
  path.line(to: NSPoint(x: 366, y: 430))
  path.curve(to: NSPoint(x: 350, y: 414), controlPoint1: NSPoint(x: 366, y: 421),
             controlPoint2: NSPoint(x: 359, y: 414))
  path.line(to: NSPoint(x: 302, y: 414))
  path.curve(to: NSPoint(x: 286, y: 430), controlPoint1: NSPoint(x: 293, y: 414),
             controlPoint2: NSPoint(x: 286, y: 421))
  path.close()
  return path
}

func previewBitmap() -> NSBitmapImageRep {
  bitmap(width: 1120, height: 660) {
    NSColor.white.setFill()
    NSRect(x: 0, y: 0, width: 1120, height: 660).fill()
    text("PinShot · A 轻盈取景", at: NSPoint(x: 36, y: 595), size: 28, color: .black)
    for (x, dark) in [(CGFloat(32), false), (CGFloat(576), true)] {
      let background = dark ? NSColor(srgbRed: 0.12, green: 0.13, blue: 0.15, alpha: 1)
        : NSColor(srgbRed: 0.95, green: 0.96, blue: 0.98, alpha: 1)
      background.setFill()
      NSBezierPath(roundedRect: NSRect(x: x, y: 48, width: 512, height: 512), xRadius: 22, yRadius: 22).fill()
      let foreground = dark ? NSColor.white : NSColor.black
      text(dark ? "深色背景" : "浅色背景", at: NSPoint(x: x + 24, y: 520), size: 15, color: foreground)
      drawPreviewIcon(pixels: 256, at: NSPoint(x: x + 128, y: 254))
      for (offset, pixels) in [(32, 16), (104, 32), (200, 64), (344, 128)] {
        drawPreviewIcon(pixels: pixels, at: NSPoint(x: x + CGFloat(offset), y: 100))
        text("\(pixels) px", at: NSPoint(x: x + CGFloat(offset), y: 76), size: 11, color: foreground)
      }
    }
  }
}

func drawPreviewIcon(pixels: Int, at point: NSPoint) {
  let icon = iconBitmap(pixels: pixels)
  let image = NSImage(size: NSSize(width: pixels, height: pixels))
  image.addRepresentation(icon)
  image.draw(in: NSRect(origin: point, size: image.size))
}

func text(_ text: String, at point: NSPoint, size: CGFloat, color: NSColor) {
  (text as NSString).draw(at: point, withAttributes: [
    .font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: color,
  ])
}
