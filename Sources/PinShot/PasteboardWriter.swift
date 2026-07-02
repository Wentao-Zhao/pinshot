import AppKit

enum PasteboardWriter {
  static func copy(image: NSImage) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.writeObjects([image])
    NSSound(named: "Pop")?.play()
  }
}

