import AppKit

enum MenuBarIcon {
  static var image: NSImage {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size)

    image.lockFocus()
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()

    // Four open corners remain recognizable at the menu bar's native 18 pt size.
    NSColor.black.setStroke()
    let corners = NSBezierPath()
    for (x, y, dx, dy) in [
      (3.0, 3.0, 1.0, 1.0), (15.0, 3.0, -1.0, 1.0),
      (3.0, 15.0, 1.0, -1.0), (15.0, 15.0, -1.0, -1.0),
    ] {
      corners.move(to: NSPoint(x: x, y: y + dy * 3.5))
      corners.line(to: NSPoint(x: x, y: y))
      corners.line(to: NSPoint(x: x + dx * 3.5, y: y))
    }
    corners.lineWidth = 1.8
    corners.lineCapStyle = .round
    corners.lineJoinStyle = .round
    corners.stroke()

    image.unlockFocus()
    image.isTemplate = true
    return image
  }
}

