import Foundation

public enum ScreenCoordinateMapper {
  public static func localPoint(fromGlobal point: Point2D, inScreenFrame screenFrame: Rect2D) -> Point2D {
    Point2D(x: point.x - screenFrame.minX, y: point.y - screenFrame.minY)
  }

  public static func localBounds(forScreenFrame screenFrame: Rect2D) -> Rect2D {
    Rect2D(x: 0, y: 0, width: screenFrame.width, height: screenFrame.height)
  }
}
