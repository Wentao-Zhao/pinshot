import AppKit

enum MenuBarIcon {
  static var image: NSImage {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size)

    image.lockFocus()
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()

    let body = NSBezierPath(roundedRect: NSRect(x: 3.5, y: 3.5, width: 11, height: 11), xRadius: 2.8, yRadius: 2.8)
    NSColor.labelColor.setStroke()
    body.lineWidth = 1.5
    body.stroke()

    let corner = NSBezierPath()
    corner.move(to: NSPoint(x: 6, y: 12))
    corner.line(to: NSPoint(x: 6, y: 14.5))
    corner.line(to: NSPoint(x: 8.5, y: 14.5))
    corner.lineWidth = 1.4
    corner.stroke()

    let pin = NSBezierPath()
    pin.move(to: NSPoint(x: 11.8, y: 5.3))
    pin.line(to: NSPoint(x: 13.8, y: 3.3))
    pin.lineWidth = 1.4
    pin.stroke()

    let dot = NSBezierPath(ovalIn: NSRect(x: 8, y: 8, width: 2, height: 2))
    dot.fill()

    image.unlockFocus()
    image.isTemplate = true
    return image
  }
}

