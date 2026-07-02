import AppKit

@MainActor
enum OCRResultWindowController {
  static func show(text: String) {
    let alert = NSAlert()
    alert.messageText = "识别结果"
    alert.informativeText = text
    alert.addButton(withTitle: "复制文字")
    alert.addButton(withTitle: "关闭")
    if alert.runModal() == .alertFirstButtonReturn {
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.setString(text, forType: .string)
    }
  }
}

