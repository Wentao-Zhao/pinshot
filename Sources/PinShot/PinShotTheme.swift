import AppKit

enum PinShotTheme {
  static let accent = NSColor(srgbRed: 0, green: 0.38, blue: 0.9, alpha: 1)
  static let surface = NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
      ? NSColor(srgbRed: 0.17, green: 0.18, blue: 0.19, alpha: 1)
      : NSColor(srgbRed: 0.98, green: 0.98, blue: 0.99, alpha: 1)
  }

  static func resolved(_ color: NSColor, for appearance: NSAppearance) -> CGColor {
    var result: CGColor!
    appearance.performAsCurrentDrawingAppearance { result = color.cgColor }
    return result
  }
}

/// A readable floating surface shared by capture, OCR and pinned-image tools.
class PinShotSurfaceView: NSVisualEffectView {
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    material = .popover
    blendingMode = .withinWindow
    state = .active
    wantsLayer = true
    layer?.cornerRadius = 12
    layer?.masksToBounds = true
    layer?.borderWidth = 0.5
    updateSurface()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateSurface()
    needsDisplay = true
  }

  private func updateSurface() {
    // CGColor loses NSColor's dynamic behavior, so resolve again on appearance changes.
    layer?.backgroundColor = PinShotTheme.resolved(PinShotTheme.surface, for: effectiveAppearance)
    layer?.borderColor = PinShotTheme.resolved(.separatorColor, for: effectiveAppearance)
  }
}
