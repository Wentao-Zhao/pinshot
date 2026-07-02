import AppKit
import CoreGraphics

struct ScreenSnapshot {
  let screen: NSScreen
  let image: NSImage
}

enum ScreenCaptureService {
  static func hasScreenCaptureAccess() -> Bool {
    CGPreflightScreenCaptureAccess()
  }

  static func requestScreenCaptureAccess() -> Bool {
    CGRequestScreenCaptureAccess()
  }

  static func capture(screen: NSScreen) -> ScreenSnapshot? {
    guard
      let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
      let cgImage = CGDisplayCreateImage(CGDirectDisplayID(screenNumber.uint32Value))
    else {
      return nil
    }

    let image = NSImage(cgImage: cgImage, size: screen.frame.size)
    return ScreenSnapshot(screen: screen, image: image)
  }
}

