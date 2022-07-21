import Foundation
import UIKit

@objc public protocol EventDescriptor: AnyObject {
  var dateInterval: DateInterval {get set}
  var isAllDay: Bool {get}
  var text: String {get}
  var attributedText: NSAttributedString? {get}
    
  var secondaryText: String? {get}
  var secondaryAttributedText: NSAttributedString? {get}
    
        // for @objc I cannot use NSLineBreakMode variable
        // convert the code to use an NSNumber instead
  //var lineBreakMode: NSLineBreakMode? {get}
  var lineBreakModeValue: NSNumber? {get set}

    
  var font : UIFont {get}
  var color: UIColor {get}
    
        // can be used to set the color of the thick line at left margin
        // defaults to color
  var marginColor: UIColor? {get}
    
        // can draw an image at the tail end of the text
        // useful for badging the event
  var cornerImage: UIImage? {get}
  var backgroundImage: UIImage? {get}

    
        // will draw a round rect in the center of the EventView
        // useful to highlight things in the event
  var statusAttributedText: NSAttributedString? {get}
  var statusBackgroundColor: UIColor? {get}


  var textColor: UIColor {get}
  var backgroundColor: UIColor {get}
  var editedEvent: EventDescriptor? {get set}
  func makeEditable() -> Self
  func commitEditing()
}
