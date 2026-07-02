import AppKit
import CoreGraphics

struct ScreenSnapshot {
  let screen: NSScreen
  var image: NSImage?

  var displayID: CGDirectDisplayID? {
    guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
      return nil
    }
    return CGDirectDisplayID(screenNumber.uint32Value)
  }
}

struct SendableCapturedImage: @unchecked Sendable {
  let cgImage: CGImage
}

enum ScreenCaptureService {
  static func hasScreenCaptureAccess() -> Bool {
    CGPreflightScreenCaptureAccess()
  }

  static func requestScreenCaptureAccess() -> Bool {
    CGRequestScreenCaptureAccess()
  }

  static func targetScreenForCapture() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main ?? NSScreen.screens.first
  }

  static func placeholderSnapshot(screen: NSScreen) -> ScreenSnapshot {
    ScreenSnapshot(screen: screen, image: nil)
  }

  static func captureImage(displayID: CGDirectDisplayID, size: NSSize) -> NSImage? {
    guard let cgImage = CGDisplayCreateImage(displayID) else {
      return nil
    }
    return NSImage(cgImage: cgImage, size: size)
  }

  static func captureCGImage(displayID: CGDirectDisplayID) -> SendableCapturedImage? {
    guard let cgImage = CGDisplayCreateImage(displayID) else {
      return nil
    }
    return SendableCapturedImage(cgImage: cgImage)
  }

  static func syntheticSnapshot(screen: NSScreen) -> ScreenSnapshot {
    let size = screen.frame.size
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
    NSRect(origin: .zero, size: size).fill()
    NSColor.systemBlue.withAlphaComponent(0.22).setFill()
    NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 420, height: 220), xRadius: 24, yRadius: 24).fill()
    image.unlockFocus()
    return ScreenSnapshot(screen: screen, image: image)
  }
}
