import Foundation

@objc public protocol EventDataSource: AnyObject {
  func eventsForDate(_ date: Date) -> [EventDescriptor]
}
