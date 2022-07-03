import UIKit

@objc open class EventView: UIView {
  @objc public var descriptor: EventDescriptor?
  public var color = SystemColors.label
  public var marginColor : UIColor?

  public var contentHeight: CGFloat {
    textView.frame.height
  }

    public private(set) lazy var imageView: UIImageView = {
        let view = UIImageView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        
        var badge : UIImage?
        if #available(iOS 13.0, *) {
            badge = UIImage.init(systemName: "sun.max")
        }
        view.tintColor = UIColor.systemGreen;
        view.image = badge;
        
        return view
    }()
    
  public private(set) lazy var textView: UITextView = {
    let view = UITextView()
    view.isUserInteractionEnabled = false
    view.backgroundColor = .clear
    view.isScrollEnabled = false
    return view
  }()

  /// Resize Handle views showing up when editing the event.
  /// The top handle has a tag of `0` and the bottom has a tag of `1`
  public private(set) lazy var eventResizeHandles = [EventResizeHandleView(), EventResizeHandleView()]

  override public init(frame: CGRect) {
    super.init(frame: frame)
    configure()
  }

  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    configure()
  }

  private func configure() {
    clipsToBounds = false
    color = tintColor
    addSubview(textView)
      addSubview(imageView)
    
    for (idx, handle) in eventResizeHandles.enumerated() {
      handle.tag = idx
      addSubview(handle)
    }
  }

  public func updateWithDescriptor(event: EventDescriptor) {
    if let attributedText = event.attributedText {
      textView.attributedText = attributedText
    } else {
      textView.text = event.text
      textView.textColor = event.textColor
      textView.font = event.font
    }
      
    if let lineBreakModeValue = event.lineBreakModeValue {
        
        var lineBreakMode: NSLineBreakMode = .byTruncatingTail
        
        switch lineBreakModeValue.intValue {
            
        case 0:
            lineBreakMode = .byWordWrapping
            
        case 1:
            lineBreakMode = .byCharWrapping
            
        case 2:
            lineBreakMode = .byClipping
            
        case 3:
            lineBreakMode = .byTruncatingHead
            
        case 4:
            lineBreakMode = .byTruncatingTail
            
        case 5:
            lineBreakMode = .byTruncatingMiddle
            
        default:
            lineBreakMode = .byTruncatingTail
            
        }
        
      textView.textContainer.lineBreakMode = lineBreakMode
        
    }
      
    descriptor = event
    backgroundColor = event.backgroundColor
    color = event.color
    marginColor = event.marginColor;
    imageView.image = event.cornerImage;
    imageView.tintColor = event.cornerImageTint;
    eventResizeHandles.forEach{
      $0.borderColor = event.color
      $0.isHidden = event.editedEvent == nil
    }
    drawsShadow = event.editedEvent != nil
    setNeedsDisplay()
    setNeedsLayout()
  }
  
  public func animateCreation() {
    transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
    func scaleAnimation() {
      transform = .identity
    }
    UIView.animate(withDuration: 0.2,
                   delay: 0,
                   usingSpringWithDamping: 0.2,
                   initialSpringVelocity: 10,
                   options: [],
                   animations: scaleAnimation,
                   completion: nil)
  }

  /**
   Custom implementation of the hitTest method is needed for the tap gesture recognizers
   located in the ResizeHandleView to work.
   Since the ResizeHandleView could be outside of the EventView's bounds, the touches to the ResizeHandleView
   are ignored.
   In the custom implementation the method is recursively invoked for all of the subviews,
   regardless of their position in relation to the Timeline's bounds.
   */
  public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    for resizeHandle in eventResizeHandles {
      if let subSubView = resizeHandle.hitTest(convert(point, to: resizeHandle), with: event) {
        return subSubView
      }
    }
    return super.hitTest(point, with: event)
  }

  override open func draw(_ rect: CGRect) {
    super.draw(rect)
    guard let context = UIGraphicsGetCurrentContext() else {
      return
    }
    context.interpolationQuality = .none
    context.saveGState()
    context.setStrokeColor(color.cgColor)
    context.setLineWidth(3)
    context.translateBy(x: 0, y: 0.5)
    let leftToRight = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .leftToRight
    let x: CGFloat = leftToRight ? 0 : frame.width - 1  // 1 is the line width
    let y: CGFloat = 0
      
        // is the stroke on the left side of the eventView
        // maybe have a variable for the color instead
      
    context.setStrokeColor(marginColor?.cgColor ?? color.cgColor)

    context.beginPath()
    context.move(to: CGPoint(x: x, y: y))
    context.addLine(to: CGPoint(x: x, y: (bounds).height))
    context.strokePath()
    context.restoreGState()
  }

  private var drawsShadow = false

  override open func layoutSubviews() {
    super.layoutSubviews()
    textView.frame = {
        if UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft {
            return CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width - 3, height: bounds.height)
        } else {
            return CGRect(x: bounds.minX + 3, y: bounds.minY, width: bounds.width - 3, height: bounds.height)
        }
    }()
    if frame.minY < 0 {
      var textFrame = textView.frame;
      textFrame.origin.y = frame.minY * -1;
      textFrame.size.height += frame.minY;
      textView.frame = textFrame;
    }
      
      
      let badgeWidth = 32.0;
      let badgeInset = 6.0;
      
      let badgeTotalWidth = (badgeWidth)
      let availableBadgeWidth = (textView.frame.size.height >= badgeTotalWidth)
      let availableBadgeHeight = ((textView.frame.size.width * 0.5) >= badgeTotalWidth)
      let availableBadgeArea = ((availableBadgeWidth == true) && (availableBadgeHeight == true))
      
      imageView.isHidden = ((imageView.image == nil) || (availableBadgeArea == false));
      
      if (imageView.isHidden == false){
          
          
          let textFrame : CGRect = textView.frame
          
              // should account for text Direction
              // if left to right, then inset the width
              // if right to left, then inset the origin
              
          if UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft {
              
              let insetFrame : CGRect = CGRect(x: textFrame.origin.x + badgeWidth,
                                               y: textFrame.origin.y,
                                               width: textFrame.size.width - badgeWidth,
                                               height: textFrame.size.height)
              
              let imageFrame = CGRect(x: textFrame.origin.x,
                                      y: textFrame.origin.y + badgeInset,
                                      width: badgeWidth - badgeInset * 2,
                                      height: badgeWidth - badgeInset * 2)
              
              textView.frame = insetFrame;
              imageView.frame = imageFrame;
              
          } else {
              
              let insetFrame : CGRect = CGRect(x: textFrame.origin.x,
                                               y: textFrame.origin.y,
                                               width: textFrame.size.width - badgeWidth,
                                               height: textFrame.size.height)
              
              let imageFrame = CGRect(x: insetFrame.origin.x +
                                      insetFrame.size.width +
                                      badgeInset,
                                      y: textFrame.origin.y + badgeInset,
                                      width: badgeWidth - badgeInset * 2,
                                      height: badgeWidth - badgeInset * 2)
              
              textView.frame = insetFrame;
              imageView.frame = imageFrame;
          }
          
      }
      
    let first = eventResizeHandles.first
    let last = eventResizeHandles.last
    let radius: CGFloat = 40
    let yPad: CGFloat =  -radius / 2
    let width = bounds.width
    let height = bounds.height
    let size = CGSize(width: radius, height: radius)
    first?.frame = CGRect(origin: CGPoint(x: width - radius - layoutMargins.right, y: yPad),
                          size: size)
    last?.frame = CGRect(origin: CGPoint(x: layoutMargins.left, y: height - yPad - radius),
                         size: size)
    
    if drawsShadow {
      applySketchShadow(alpha: 0.13,
                        blur: 10)
    }
  }

  private func applySketchShadow(
    color: UIColor = .black,
    alpha: Float = 0.5,
    x: CGFloat = 0,
    y: CGFloat = 2,
    blur: CGFloat = 4,
    spread: CGFloat = 0)
  {
    layer.shadowColor = color.cgColor
    layer.shadowOpacity = alpha
    layer.shadowOffset = CGSize(width: x, height: y)
    layer.shadowRadius = blur / 2.0
    if spread == 0 {
      layer.shadowPath = nil
    } else {
      let dx = -spread
      let rect = bounds.insetBy(dx: dx, dy: dx)
      layer.shadowPath = UIBezierPath(rect: rect).cgPath
    }
  }
}
