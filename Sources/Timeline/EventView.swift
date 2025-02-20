import UIKit

@objc open class EventView: UIView {
    @objc public var descriptor: EventDescriptor?
    public var color = SystemColors.label
    public var marginColor : UIColor?
    private var kInset : CGFloat = 8
    private var rightAttributedText : NSAttributedString?
    private var leftAttributedText : NSAttributedString?
    private var lineBreakMode : NSLineBreakMode = .byTruncatingTail
    private var cornerImages : [UIImage]?
    private var backgroundImage : UIImage?
    private var backgroundImageAlpha : CGFloat = 1
    
    
    
    public var contentHeight: CGFloat {
        bounds.height - (2*kInset)
    }
    
    
    public func fittingHeightFor(maxTextLines: NSInteger) -> CGFloat {
            // if zero or less, use all lines
        guard var leftAttText = leftAttributedText else {
            return kInset * 2
        }
        
        if (maxTextLines > 0){
            let components = leftAttText.string.components(separatedBy: "\n")
            var strings = [String]()
            for string in components {
                if (strings.count == maxTextLines){
                    break
                }
                strings.append(string)
            }
            let attributes = leftAttText.attributes(at: 0, effectiveRange: nil)
            let string = strings.joined(separator: "\n")
            leftAttText = NSAttributedString.init(string: string, attributes: attributes)
        }
        
        let leftTextRect = leftAttText.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                                 height:  CGFloat.greatestFiniteMagnitude),
                                                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                    context: nil)
        
        return leftTextRect.height + kInset*2
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
        cornerImages = event.cornerImages;
        backgroundImage = event.backgroundImage
        backgroundImageAlpha = event.backgroundImageAlpha
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
    
    
    private func rectByCenteringSizeInRectWithoutScaling(rect: CGRect, size : CGSize) -> CGRect{
        let extraWidth = CGRectGetWidth(rect) - size.width;
        let extraHeight = CGRectGetHeight(rect) - size.height;
        
        var result = rect;
        result.size = size;
        result.origin.x += CGFloat(floorf(Float(extraWidth) / 2.0));
        result.origin.y += CGFloat(floorf(Float(extraHeight) / 2.0));
        
        return result;
    }

    
    private func centerPoint(_ r: CGRect) -> CGPoint{
        let x = r.origin.x + r.size.width/CGFloat(2.0);
        let y = r.origin.y + r.size.height/CGFloat(2.0);
        return CGPoint(x: x, y: y)
    }
    
    
    public func pointOnCornerImageAtIndex(_ p: CGPoint) -> NSInteger{
        
        let contentFrame = CGRect(x: bounds.minX + kInset,
                                  y: bounds.minY + kInset,
                                  width: bounds.width - 2 * kInset,
                                  height: bounds.height - 2 * kInset)
        
        guard let images = cornerImages else {
            return NSNotFound
        }
        
        
        for index in 0 ..< images.count {
            
            let imageRect = cornerImageFrame(contentFrame,
                                             cornerImages: images,
                                             imageIndex: index,
                                             leftText: leftAttributedText)
            
            if (imageRect.isEmpty == true){
                continue
            }
            
            if (imageRect.contains(p) == true){
                return index
            }
        }
        
        return NSNotFound
    }
    
    
    public func pointOnStatus(_ p: CGPoint) -> Bool{
        let contentFrame = CGRect(x: bounds.minX + kInset,
                                  y: bounds.minY + kInset,
                                  width: bounds.width - 2 * kInset,
                                  height: bounds.height - 2 * kInset)
        
        let statusRect = statusFrame(contentFrame,
                                     cornerImages: cornerImages,
                                     statusText: descriptor?.statusAttributedText,
                                     statusBackgroundColor: descriptor?.statusBackgroundColor,
                                     leftText: leftAttributedText)
        if (statusRect.isEmpty == true){
            return false
        }
        return statusRect.contains(p)
    }
    
    
    
    private func statusFrame(_ contentFrame: CGRect,
                                cornerImages: [UIImage]?,
                                statusText: NSAttributedString?,
                                statusBackgroundColor: UIColor?,
                                leftText: NSAttributedString?) -> CGRect{
        
        if (statusBackgroundColor == nil){
            return CGRect.zero
        }
        
        guard let statusPending = statusText else {
            return CGRect.zero
        }
        
            // get the badge space
        let imageWidth = cornerImageWidth(contentFrame,
                                          cornerImages: cornerImages,
                                          leftText: leftText)
        
        let xInset : CGFloat = 8
        let yInset : CGFloat = 6
        var statusRect = contentFrame.insetBy(dx: xInset, dy: yInset)
        
        let pendingSize = CGSize(width:  statusRect.size.width, height: CGFloat.greatestFiniteMagnitude)
        let pendingRect = statusPending.boundingRect(with: pendingSize,
                                                     options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin],
                                                     context: nil)
        
        let maxWidth = Float(statusRect.width - imageWidth - xInset - xInset);
        var width = fminf(Float(statusRect.size.width), Float(pendingRect.size.width));
        if (width > maxWidth){
            width = maxWidth;
        }
        let height = fminf(Float(statusRect.size.height), Float(pendingRect.size.height));
        
        statusRect.size.width = CGFloat(width)
        statusRect.size.height = CGFloat(height)
        
            // adjust the origin
        let rightToLeft = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft
        
            // left to right
        
        let yPoint = contentFrame.minY + yInset/2
        var xPoint = contentFrame.maxX - imageWidth - kInset - statusRect.width - xInset/2
        if (rightToLeft == true) {
            xPoint = contentFrame.minX + imageWidth + kInset + xInset/2
        }
        statusRect.origin.x = xPoint
        statusRect.origin.y = yPoint
        
        return statusRect
    }
    
    private func leftTextFrame(_ contentFrame: CGRect,
                               text: NSAttributedString?) -> CGRect{
        
        let leftTextRect = text?.boundingRect(with: CGSize(width: contentFrame.width,
                                                                 height:  CGFloat.greatestFiniteMagnitude),
                                                    options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin],
                                                    context: nil) ?? CGRect(x: contentFrame.minY,
                                                                            y: contentFrame.minY,
                                                                            width: 0,
                                                                            height: contentFrame.size.height)
        return leftTextRect
    }
    
    
    let defaultImageWidth : CGFloat = 24
    private func cornerImageWidth(_ contentFrame: CGRect,
                                  cornerImages: [UIImage]?,
                                  leftText: NSAttributedString?) -> CGFloat{
        
        guard let images = cornerImages else {
            return 0
        }
        
        if (images.count == 0){
            return 0
        }
        
        let leftTextRect = leftTextFrame(contentFrame,
                                         text: leftText)
        
        var imageWidth = defaultImageWidth
        if ((contentFrame.width - leftTextRect.width) < imageWidth){
            imageWidth = 0
        }
        if (contentFrame.height < imageWidth){
            imageWidth = 0
        }
        
        return imageWidth
    }
    
    
    private func rightTextFrame(_ contentFrame: CGRect,
                                cornerImages: [UIImage]?,
                                statusText: NSAttributedString?,
                                statusBackgroundColor: UIColor?,
                                leftText: NSAttributedString?) -> CGRect{
        
        let leftTextRect = leftTextFrame(contentFrame,
                                         text: leftText)
        
            // get the badge space
        let imageWidth = cornerImageWidth(contentFrame,
                                          cornerImages: cornerImages,
                                          leftText: leftText)
        
        let statusRect = statusFrame(contentFrame,
                                     cornerImages: cornerImages,
                                     statusText: statusText,
                                     statusBackgroundColor: statusBackgroundColor,
                                     leftText: leftText)
        
        let rightToLeft = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft
        
        
        var yPoint = contentFrame.minY
        if (statusRect.isEmpty == false){
            yPoint = statusRect.origin.y + statusRect.height + kInset
        }
        
            // left to right
        var rightTextRect = CGRect(x: leftTextRect.maxX + kInset,
                                   y: yPoint,
                                   width: contentFrame.width - leftTextRect.width - kInset - imageWidth,
                                   height: contentFrame.maxY - yPoint)
        
        if (rightToLeft == true) {
            rightTextRect = CGRect(x: contentFrame.minX + imageWidth,
                                   y: yPoint,
                                   width: contentFrame.width - leftTextRect.width - kInset - imageWidth,
                                   height: contentFrame.maxY - yPoint)
        }
        
        
        if (rightTextRect.width/contentFrame.width < 0.25){
                // don't draw if less than a quarter content width
            rightTextRect = CGRect.zero
        }
        
        return rightTextRect
    }
    
    
    private func cornerImageFrame(_ contentFrame: CGRect,
                                  cornerImages: [UIImage]?,
                                  imageIndex: NSInteger,
                                  leftText: NSAttributedString?) -> CGRect{
        
        guard let images = cornerImages else {
            return CGRect.zero
        }
        
        if imageIndex == NSNotFound {
            return CGRect.zero
        }
        
        if (imageIndex >= images.count){
            return CGRect.zero
        }
        
        let cornerImage = images[imageIndex]
        
            // get the badge space
        let imageWidth = cornerImageWidth(contentFrame,
                                          cornerImages: cornerImages,
                                          leftText: leftText)
        if (imageWidth < 8){
            return CGRect.zero
        }
        
        
        let rightToLeft = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft
        
            // left to right
        var xPoint = contentFrame.maxX - imageWidth
        if (rightToLeft == true){
            xPoint = contentFrame.minX
        }
        
        var imageFrame = CGRect(x: xPoint,
                                y: contentFrame.origin.y,
                                width: imageWidth,
                                height: contentFrame.height)
        
        let spacer : CGFloat = 4
        imageFrame = maximalRectWithoutChangingAspectRatio(boundary: imageFrame, shape : cornerImage.size)
        imageFrame.origin.y = contentFrame.origin.y + imageWidth * CGFloat(imageIndex) + spacer * CGFloat(imageIndex)
        
            // if the image is not entirely in the content, then reject
        if (contentFrame.contains(imageFrame) == false){
            return CGRect.zero
        }
        
        return imageFrame
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
        
        
        backgroundImage?.draw(in: backgroundImageFrame,
                              blendMode: .normal,
                              alpha: backgroundImageAlpha)
        
            // draw the left text first
        leftAttributedText?.draw(with: contentFrame,
                          options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin],
                          context: nil)
        
            // left to right
        let rightTextRect = rightTextFrame(contentFrame,
                                           cornerImages: cornerImages,
                                           statusText: descriptor?.statusAttributedText,
                                           statusBackgroundColor: descriptor?.statusBackgroundColor,
                                           leftText: leftAttributedText)
        
        
        if (rightTextRect.isEmpty == false){
            rightAttributedText?.draw(with: rightTextRect,
                                      options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin],
                                      context: nil)
        }
        
        
        if let images = cornerImages {
            
            for index in 0 ..< images.count {
                let imageFrame = cornerImageFrame(contentFrame,
                                                  cornerImages: images,
                                                  imageIndex: index,
                                                  leftText: leftAttributedText)
                if (imageFrame.isEmpty == false){
                    let cornerImage = images[index]
                    cornerImage.draw(in: imageFrame)
                }
                
            }
            
        }
        
        
        
            // status string
        
        let statusRect = statusFrame(contentFrame,
                                     cornerImages: cornerImages,
                                     statusText: descriptor?.statusAttributedText,
                                     statusBackgroundColor: descriptor?.statusBackgroundColor,
                                     leftText: leftAttributedText)
        if (statusRect.isEmpty == false){
            
                // draw background pill
            let pillRect = statusRect.insetBy(dx: -6, dy: -3)
            let circlePath = UIBezierPath(roundedRect: pillRect,
                                          cornerRadius: pillRect.size.height/2)
            
            let statusBackgroundColor = descriptor?.statusBackgroundColor ?? UIColor.clear
            
            context.saveGState()
            
                // add a margin equal to the background color in case it is over some text
            if let background = backgroundColor {
                    // add a margin equal to the background color
                context.setStrokeColor(background.cgColor)
                circlePath.lineWidth = 6
                circlePath.stroke()
            }
            
            
                // add a margin
            var lineColor = UIColor.black
            if (UITraitCollection.current.userInterfaceStyle == .dark){
                lineColor = UIColor.white
            }
            lineColor = lineColor.withAlphaComponent(0.55)
            context.setStrokeColor(lineColor.cgColor)
            circlePath.lineWidth = 2
            circlePath.stroke()
            
            
            context.setFillColor(statusBackgroundColor.cgColor)
            circlePath.fill()
            
            descriptor?.statusAttributedText!.draw(with: statusRect,
                                                   options: [NSStringDrawingOptions.truncatesLastVisibleLine,
                                                             NSStringDrawingOptions.usesLineFragmentOrigin],
                                                   context: nil)
            
            context.restoreGState()
            
        }
        
        
            // overlay text
        
        if let overlayString = descriptor?.overlayText {
            
                // target rect
            let overlayRect = rect.insetBy(dx: 20, dy: 20)
            
            if ((overlayRect.width > 0) &&
                (overlayRect.height > 0)){
                
                    // draw string
                let paragraphStyle: NSMutableParagraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                paragraphStyle.lineBreakMode = .byWordWrapping
                paragraphStyle.alignment = .center
                let font = UIFont.systemFont(ofSize: 12, weight: .heavy)
                    //paragraphStyle.minimumLineHeight = overlayRect.height / 2 + font.lineHeight / 2
                let attributes = [NSAttributedString.Key.paragraphStyle: paragraphStyle,
                                  NSAttributedString.Key.foregroundColor: UIColor.white,
                                  NSAttributedString.Key.font: font]
                
                let overlayAttString = NSAttributedString(string: overlayString,
                                                          attributes: attributes)
                
                let overlaySize = CGSize(width:  overlayRect.size.width, height: CGFloat.greatestFiniteMagnitude)
                let pendingRect = overlayAttString.boundingRect(with: overlaySize,
                                                                options: [.usesFontLeading, .usesLineFragmentOrigin],
                                                                context: nil)
                
                
                if ((pendingRect.width <= overlayRect.width) &&
                    (pendingRect.height <= overlayRect.height) &&
                    (pendingRect.width > 0) &&
                    (pendingRect.height > 0)){
                    
                    let overlayDrawRect = rectByCenteringSizeInRectWithoutScaling(rect: overlayRect, size: pendingRect.size)
                    
                        // draw background
                        // outset by 8
                    
                    let overlayBackgroundRect = overlayDrawRect.insetBy(dx: -8, dy: -8)
                    let backgroundPath = UIBezierPath(roundedRect: overlayBackgroundRect, cornerRadius: 10)
                    let overlayBackgroundColor = UIColor.black.withAlphaComponent(0.7)
                    
                    context.saveGState()
                    
                    context.setFillColor(overlayBackgroundColor.cgColor)
                    backgroundPath.fill()
                    
                    overlayAttString.draw(in: overlayDrawRect)
                    
                    context.restoreGState()
                    
                }
            }
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
