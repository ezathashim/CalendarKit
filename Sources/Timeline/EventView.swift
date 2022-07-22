import UIKit

@objc open class EventView: UIView {
    @objc public var descriptor: EventDescriptor?
    public var color = SystemColors.label
    public var marginColor : UIColor?
    private var kInset : CGFloat = 8
    private var rightAttributedText : NSAttributedString?
    private var leftAttributedText : NSAttributedString?
    private var lineBreakMode : NSLineBreakMode = .byTruncatingTail
    private var cornerImage : UIImage?
    private var backgroundImage : UIImage?
    
    
    
    public var contentHeight: CGFloat {
        bounds.height - (2*kInset)
    }
    
    
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
        
        for (idx, handle) in eventResizeHandles.enumerated() {
            handle.tag = idx
            addSubview(handle)
        }
    }
    
    
    override public var frame: CGRect {
        get {
            return super.frame
        }
        set {
            super.frame = newValue
            setNeedsDisplay()
        }
    }
    
    
    
    public func updateWithDescriptor(event: EventDescriptor) {
        
        if let lineBreakModeValue = event.lineBreakModeValue {
            
            var breakMode: NSLineBreakMode = .byTruncatingTail
            
            switch lineBreakModeValue.intValue {
                
            case 0:
                breakMode = .byWordWrapping
                
            case 1:
                breakMode = .byCharWrapping
                
            case 2:
                breakMode = .byClipping
                
            case 3:
                breakMode = .byTruncatingHead
                
            case 4:
                breakMode = .byTruncatingTail
                
            case 5:
                breakMode = .byTruncatingMiddle
                
            default:
                breakMode = .byTruncatingTail
                
            }
            
            lineBreakMode = breakMode
            
        }
        
        
        let rightToLeft = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft
        
        if let attText = event.attributedText {
            leftAttributedText = attText
            
        } else {
            var alignment = NSTextAlignment.left
            if (rightToLeft){
                alignment = NSTextAlignment.right
            }
            let paragraphStyle: NSMutableParagraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
            paragraphStyle.lineBreakMode = lineBreakMode
            paragraphStyle.alignment = alignment
            let attributes = [NSAttributedString.Key.paragraphStyle: paragraphStyle,
                              NSAttributedString.Key.foregroundColor: event.textColor,
                              NSAttributedString.Key.font: event.font]
            let attText = NSAttributedString(string: event.text,
                                             attributes: attributes)
            leftAttributedText = attText
        }
        
        if let secondaryAttText = event.secondaryAttributedText {
            rightAttributedText = secondaryAttText
            
        } else {
            if let secondaryText = event.secondaryText {
                var alignment = NSTextAlignment.right
                if (rightToLeft){
                    alignment = NSTextAlignment.left
                }
                let paragraphStyle: NSMutableParagraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                paragraphStyle.lineBreakMode = lineBreakMode
                paragraphStyle.alignment = alignment
                let attributes = [NSAttributedString.Key.paragraphStyle: paragraphStyle,
                                  NSAttributedString.Key.foregroundColor: event.textColor,
                                  NSAttributedString.Key.font: event.font]
                let attText = NSAttributedString(string: secondaryText,
                                                 attributes: attributes)
                rightAttributedText = attText
            }
            
        }
        
        descriptor = event
        backgroundColor = event.backgroundColor
        color = event.color
        marginColor = event.marginColor;
        cornerImage = event.cornerImage;
        backgroundImage = event.backgroundImage
        eventResizeHandles.forEach{
            $0.borderColor = event.color
            $0.isHidden = event.editedEvent == nil
        }
        drawsShadow = event.editedEvent != nil
        setNeedsDisplay()
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
    
    private func maximalRectWithoutChangingAspectRatio(boundary: CGRect, shape : CGSize) -> CGRect{
        
        let innerAspect = shape.width / shape.height;
        let outerAspect = boundary.size.width / boundary.size.height;
        
        let squatterThanBoundary = (innerAspect > outerAspect);
        
        var scale : CGFloat = 0
        if (squatterThanBoundary){
            scale = boundary.size.width / shape.width
        }else{
            scale = boundary.size.height / shape.height
        }
        
        var result = CGRect(x: 0,
                            y: 0,
                            width: shape.width * scale,
                            height: shape.height * scale)
        
        if (squatterThanBoundary) {
            result.origin.x = boundary.origin.x;
            result.origin.y = boundary.origin.y + (boundary.size.height - result.size.height)/CGFloat(2.0);
        } else {
            result.origin.y = boundary.origin.y;
            result.origin.x = boundary.origin.x + (boundary.size.width - result.size.width)/CGFloat(2.0);
        }
        return result;
    }
    
    
    private func centerPoint(_ r: CGRect) -> CGPoint{
        let x = r.origin.x + r.size.width/CGFloat(2.0);
        let y = r.origin.y + r.size.height/CGFloat(2.0);
        return CGPoint(x: x, y: y)
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
        
        
            // should just draw the string and image instead of using a UITextView and UIImageView
            // in old Nopali, the EventView does all this, so I could just copy it
        let contentFrame = CGRect(x: rect.minX + kInset,
                                  y: rect.minY + kInset,
                                  width: rect.width - 2 * kInset,
                                  height: rect.height - 2 * kInset)
        
        
        let backgroundImageInset = kInset / 2
        var backgroundImageFrame = contentFrame.insetBy(dx: backgroundImageInset,
                                                        dy: backgroundImageInset)
        if let backingImage = backgroundImage{
            backgroundImageFrame = maximalRectWithoutChangingAspectRatio(boundary: backgroundImageFrame, shape : backingImage.size)
        }
        
        backgroundImage?.draw(in: backgroundImageFrame)
        
        let rightToLeft = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft
        
        let leftAttText = leftAttributedText
        let rightAttText = rightAttributedText
        
        
            // draw the left text first
        leftAttText?.draw(with: contentFrame,
                          options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin],
                          context: nil)
        
        
        let leftTextRect = leftAttText?.boundingRect(with: CGSize(width: contentFrame.width,
                                                                  height:  CGFloat.greatestFiniteMagnitude),
                                                     options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                     context: nil) ?? CGRect(x: contentFrame.minY,
                                                                             y: contentFrame.minY,
                                                                             width: 0,
                                                                             height: contentFrame.size.height)
        
            // get the badge space
        var imageWidth = 20.0
        if ((contentFrame.width - leftTextRect.width) < imageWidth){
            imageWidth = 0
        }
        if (contentFrame.height < imageWidth){
            imageWidth = 0
        }
        
        if (cornerImage == nil){
            imageWidth = 0
        }
        
        
            // left to right
        var rightTextRect = CGRect(x: leftTextRect.maxX + kInset,
                                   y: contentFrame.minY,
                                   width: contentFrame.width - leftTextRect.width - kInset - imageWidth,
                                   height: contentFrame.size.height)
        
        if (rightToLeft == true) {
            rightTextRect = CGRect(x: contentFrame.minX + imageWidth,
                                   y: contentFrame.minY,
                                   width: contentFrame.width - leftTextRect.width - kInset - imageWidth,
                                   height: contentFrame.size.height)
        }
        
        
        if (rightTextRect.width/contentFrame.width > 0.25){
            rightAttText?.draw(with: rightTextRect,
                               options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin],
                               context: nil)
        }
        
        
        
        if (imageWidth > 8){
            
                // left to right
            var imageFrame = CGRect(x: rightTextRect.maxX + kInset,
                                    y: contentFrame.origin.y,
                                    width: imageWidth,
                                    height: contentFrame.height)
            
            if (rightToLeft == true) {
                imageFrame = CGRect(x: contentFrame.maxX - imageWidth - kInset,
                                    y: contentFrame.origin.y,
                                    width: imageWidth,
                                    height: contentFrame.height)
            }
            
            imageFrame = imageFrame.insetBy(dx: 2, dy: 0)
            
            if let badgeImage = cornerImage{
                imageFrame = maximalRectWithoutChangingAspectRatio(boundary: imageFrame, shape : badgeImage.size)
                imageFrame.origin.y = contentFrame.origin.y
                badgeImage.draw(in: imageFrame)
            }
            
        }
        
        
        
            // status string
        
        let statusPending = descriptor?.statusAttributedText
        let statusBackgroundColor = descriptor?.statusBackgroundColor
        
        
        if ((statusPending != nil) && (statusBackgroundColor != nil)) {
            
                // draw over everything
            
            var statusRect = rect.insetBy(dx: 6, dy: 6)
            
            let pendingSize = CGSize(width:  statusRect.size.width, height: CGFloat.greatestFiniteMagnitude)
            let pendingRect = statusPending!.boundingRect(with: pendingSize,
                                                          options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                          context: nil)
            
            
            let width = fminf(Float(statusRect.size.width), Float(pendingRect.size.width));
            let height = fminf(Float(statusRect.size.height), Float(pendingRect.size.height));
            
            statusRect.size.width = CGFloat(width)
            statusRect.size.height = CGFloat(height)
            
                // adjust the origin to center the pill
            statusRect.origin.x = (rect.size.width - statusRect.size.width)/2;
            
            
            
            let alpha = 1.0
            
            let statusColor = statusBackgroundColor!.withAlphaComponent(alpha)
            
            
            
                // draw a pill behind the text
            let pillRect = statusRect.insetBy(dx: -3, dy: -3)
            let circlePath = UIBezierPath(roundedRect: pillRect,
                                          cornerRadius: pillRect.size.height/2)
            
            
            context.saveGState()
            
            context.setStrokeColor(UIColor.white.cgColor)
            context.setFillColor(statusColor.cgColor)
            
            circlePath.stroke()
            circlePath.fill()
            
            
            statusPending!.draw(with: statusRect,
                                options: [NSStringDrawingOptions.truncatesLastVisibleLine,
                                          NSStringDrawingOptions.usesLineFragmentOrigin],
                                context: nil)
            
            context.restoreGState()
            
        }
        
    }
    
    private var drawsShadow = false
    
    override open func layoutSubviews() {
        super.layoutSubviews()
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
