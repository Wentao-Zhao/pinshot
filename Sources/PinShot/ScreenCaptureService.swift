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

struct ScreenCaptureTarget {
  let screen: NSScreen
  let displayID: CGDirectDisplayID
  let size: NSSize
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

  static func captureTargets() -> [ScreenCaptureTarget] {
    NSScreen.screens.compactMap { screen in
      guard let displayID = ScreenSnapshot(screen: screen, image: nil).displayID else {
        return nil
      }
      return ScreenCaptureTarget(screen: screen, displayID: displayID, size: screen.frame.size)
    }
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
