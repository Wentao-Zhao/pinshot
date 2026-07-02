import AppKit
import PinShotCore

enum ScreenshotRenderer {
  static func render(
    snapshot: ScreenSnapshot,
    selectionRect: NSRect,
    annotations: [AnnotationItem]
  ) -> NSImage {
    let image = NSImage(size: selectionRect.size)
    image.lockFocus()

    snapshot.image.draw(
      in: NSRect(origin: .zero, size: selectionRect.size),
      from: selectionRect,
      operation: .copy,
      fraction: 1
    )

    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(rect: NSRect(origin: .zero, size: selectionRect.size)).addClip()
    let offset = NSPoint(x: -selectionRect.minX, y: -selectionRect.minY)
    for item in annotations {
      AnnotationDrawing.draw(item: item, offset: offset)
    }
    NSGraphicsContext.restoreGraphicsState()

    image.unlockFocus()
    return image
  }
}

enum PNGWriter {
  static func write(image: NSImage, to url: URL) throws {
    guard
      let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let data = bitmap.representation(using: .png, properties: [:])
    else {
      throw PNGWriterError.unableToEncode
    }
    try data.write(to: url, options: .atomic)
  }
}

enum PNGWriterError: LocalizedError {
  case unableToEncode

  var errorDescription: String? {
    "无法编码 PNG 图片"
  }
}

