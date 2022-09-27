import CoreGraphics

public final class EventLayoutAttributes {
  public let descriptor: EventDescriptor
  public var frame = CGRect.zero
  public var columnIndex : NSInteger = 0

  public init(_ descriptor: EventDescriptor) {
    self.descriptor = descriptor
  }
}
