import AppKit
import PinShotCore

final class OCRStatusPanelView: PinShotSurfaceView {
  var onClose: (() -> Void)?

  private let header = NSStackView()
  private let spinner = NSProgressIndicator()
  private let titleLabel = NSTextField(labelWithString: "")
  private let copyAllButton = NSButton(title: "复制全部", target: nil, action: nil)
  private let closeButton = NSButton(title: "×", target: nil, action: nil)
  private let scrollView = NSScrollView()
  private let resultView = OCRResultTextView(frame: .zero)
  private var panelState = OCRPanelState.hidden

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    buildContent()
    update(state: .hidden)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  func update(state: OCRPanelState) {
    panelState = state
    let recognizing = state == .recognizing
    let text = state.recognizedText
    spinner.isHidden = !recognizing
    closeButton.isHidden = recognizing
    copyAllButton.isHidden = text == nil
    scrollView.isHidden = text == nil
    titleLabel.stringValue = text == nil ? state.displayText : "识别文字 · 选中文字按 ⌘C"
    if recognizing {
      spinner.startAnimation(nil)
    } else {
      spinner.stopAnimation(nil)
    }
    resultView.string = text ?? ""
    resultView.setSelectedRange(NSRange(location: 0, length: 0))
    resultView.scrollRangeToVisible(NSRange(location: 0, length: 0))
  }

  func preferredSize(in availableSize: NSSize) -> NSSize {
    let width: CGFloat
    let height: CGFloat
    if let text = panelState.recognizedText {
      width = 384
      height = text.count > 160 || text.split(maxSplits: 3, whereSeparator: \.isNewline).count > 3 ? 224 : 132
    } else {
      width = panelState == .recognizing ? 148 : 184
      height = 44
    }
    return NSSize(width: min(width, availableSize.width), height: min(height, availableSize.height))
  }

  private func buildContent() {
    header.orientation = .horizontal
    header.alignment = .centerY
    header.spacing = 8

    spinner.style = .spinning
    spinner.controlSize = .small
    spinner.isDisplayedWhenStopped = false

    titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
    titleLabel.textColor = .secondaryLabelColor
    titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    copyAllButton.bezelStyle = .rounded
    copyAllButton.controlSize = .small
    copyAllButton.target = self
    copyAllButton.action = #selector(copyAll)

    closeButton.isBordered = false
    closeButton.font = .systemFont(ofSize: 17, weight: .medium)
    closeButton.contentTintColor = .secondaryLabelColor
    closeButton.setAccessibilityLabel("关闭识别结果")
    closeButton.target = self
    closeButton.action = #selector(closeClicked)

    [spinner, titleLabel, copyAllButton, closeButton].forEach { header.addArrangedSubview($0) }

    scrollView.drawsBackground = false
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true
    resultView.configure()
    scrollView.documentView = resultView

    let content = NSStackView(views: [header, scrollView])
    content.orientation = .vertical
    content.alignment = .leading
    content.spacing = 5
    content.translatesAutoresizingMaskIntoConstraints = false
    addSubview(content)

    NSLayoutConstraint.activate([
      content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
      content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
      content.topAnchor.constraint(equalTo: topAnchor, constant: 8),
      content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
      header.widthAnchor.constraint(equalTo: content.widthAnchor),
      header.heightAnchor.constraint(equalToConstant: 28),
      scrollView.widthAnchor.constraint(equalTo: content.widthAnchor),
      closeButton.widthAnchor.constraint(equalToConstant: 20),
      spinner.widthAnchor.constraint(equalToConstant: 16),
      spinner.heightAnchor.constraint(equalToConstant: 16),
    ])
  }

  @objc private func copyAll() {
    if let text = panelState.recognizedText {
      PasteboardWriter.copy(text: text)
    }
  }

  @objc private func closeClicked() {
    onClose?()
  }
}

final class OCRResultTextView: NSTextView {
  func configure() {
    isEditable = false
    isSelectable = true
    isRichText = false
    drawsBackground = false
    isVerticallyResizable = true
    isHorizontallyResizable = false
    autoresizingMask = [.width]
    textContainerInset = NSSize(width: 0, height: 4)
    textContainer?.lineFragmentPadding = 0
    textContainer?.widthTracksTextView = true
    textColor = .labelColor
    insertionPointColor = .labelColor
    selectedTextAttributes = [
      .backgroundColor: NSColor.selectedTextBackgroundColor,
      .foregroundColor: NSColor.selectedTextColor,
    ]
    font = .systemFont(ofSize: 13)
    setAccessibilityLabel("识别结果")
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
  override var needsPanelToBecomeKey: Bool { true }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if window?.firstResponder === self, handleKeyEquivalent(event) { return true }
    return super.performKeyEquivalent(with: event)
  }

  override func keyDown(with event: NSEvent) {
    if !handleKeyEquivalent(event) { super.keyDown(with: event) }
  }

  override func copy(_ sender: Any?) {
    let text = string as NSString
    let selection = selectedRange()
    guard selection.length > 0, NSMaxRange(selection) <= text.length else { return }
    PasteboardWriter.copy(text: text.substring(with: selection))
  }

  func handleKeyEquivalent(_ event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
    guard modifiers == .command else { return false }
    switch event.charactersIgnoringModifiers?.lowercased() {
    case "c": copy(nil)
    case "a": selectAll(nil)
    default: return false
    }
    return true
  }
}
