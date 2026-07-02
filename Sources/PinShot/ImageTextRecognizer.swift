import AppKit
import Vision

enum ImageTextRecognizer {
  static func recognizedText(from image: NSImage) async -> String? {
    await Task.detached(priority: .utility) {
      autoreleasepool {
        guard let cgImage = preparedCGImage(from: image) else {
          return nil
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
          try handler.perform([request])
        } catch {
          return nil
        }

        let text = request.results?
          .compactMap { $0.topCandidates(1).first?.string }
          .joined(separator: "\n")
          .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
      }
    }.value
  }

  private static func preparedCGImage(from image: NSImage, maxDimension: Int = 2200) -> CGImage? {
    var proposedRect = NSRect(origin: .zero, size: image.size)
    guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
      return nil
    }

    let longestSide = max(cgImage.width, cgImage.height)
    guard longestSide > maxDimension else {
      return cgImage
    }

    let scale = CGFloat(maxDimension) / CGFloat(longestSide)
    let width = max(1, Int(CGFloat(cgImage.width) * scale))
    let height = max(1, Int(CGFloat(cgImage.height) * scale))
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
      return cgImage
    }

    context.interpolationQuality = .medium
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage() ?? cgImage
  }
}
