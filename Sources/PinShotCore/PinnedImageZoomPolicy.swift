import Foundation

public enum PinnedImageZoomPolicy {
  public static func frame(
    byZooming frame: Rect2D,
    at anchor: Point2D,
    scrollDelta: Double,
    precise: Bool,
    minimumWidth: Double,
    minimumHeight: Double,
    visibleFrame: Rect2D
  ) -> Rect2D {
    guard frame.width > 0, frame.height > 0, scrollDelta.isFinite, scrollDelta != 0,
          visibleFrame.width > 0, visibleFrame.height > 0 else { return frame }
    let ratio = frame.width / frame.height
    let maximumWidth = min(visibleFrame.width, visibleFrame.height * ratio)
    let minimumWidth = min(max(minimumWidth, minimumHeight * ratio), maximumWidth)
    let exponent = min(max(scrollDelta * (precise ? 0.008 : 0.12), -4), 4)
    let width = min(max(frame.width * exp(exponent), minimumWidth), maximumWidth)
    let height = width / ratio
    let fractionX = min(max((anchor.x - frame.x) / frame.width, 0), 1)
    let fractionY = min(max((anchor.y - frame.y) / frame.height, 0), 1)
    return Rect2D(
      x: min(max(anchor.x - width * fractionX, visibleFrame.minX), visibleFrame.maxX - width),
      y: min(max(anchor.y - height * fractionY, visibleFrame.minY), visibleFrame.maxY - height),
      width: width, height: height
    )
  }
}
