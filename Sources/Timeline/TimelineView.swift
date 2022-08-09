import UIKit

public protocol TimelineViewDelegate: AnyObject {
    func timelineView(_ timelineView: TimelineView, didTapAt date: Date, columnIndex: NSInteger)
    func timelineView(_ timelineView: TimelineView, didLongPressAt date: Date, columnIndex: NSInteger)
    func timelineView(_ timelineView: TimelineView, didTap event: EventView)
    func timelineView(_ timelineView: TimelineView, didTapCornerImage event: EventView, imageIndex : NSInteger)
    func timelineView(_ timelineView: TimelineView, didLongPress event: EventView)
    func openIntervalForDate(_ date: Date) -> NSDateInterval
    func numberOfColumnsForDate(_ date: Date)  -> NSInteger
    func titleOfColumnForDate(_ date: Date, columnIndex: NSInteger) -> NSString
    func columnIndexForDescriptor(_ descriptor: EventDescriptor, date: Date) -> NSInteger
    func timelineView(_ timelineView: TimelineView, event: EventView, menuConfigurationAtStatusPoint point: CGPoint) -> UIContextMenuConfiguration?
    func timelineView(_ timelineView: TimelineView, event: EventView, menuConfigurationAtCornerImagePoint point: CGPoint, imageIndex : NSInteger) -> UIContextMenuConfiguration?
}

public final class TimelineView: UIView, UIContextMenuInteractionDelegate {
    public weak var delegate: TimelineViewDelegate?
    public let timeSidebarWidth : CGFloat = 53
    
    public var date = Date() {
        didSet {
            setNeedsLayout()
        }
    }
    
    private var currentTime: Date {
        Date()
    }
    
    private var eventViews = [EventView]()
    public private(set) var regularLayoutAttributes = [EventLayoutAttributes]()
    public private(set) var allDayLayoutAttributes = [EventLayoutAttributes]()
    
    public var layoutAttributes: [EventLayoutAttributes] {
        get {
            allDayLayoutAttributes + regularLayoutAttributes
        }
        set {
            
                // update layout attributes by separating allday from non all day events
            allDayLayoutAttributes.removeAll()
            regularLayoutAttributes.removeAll()
            for anEventLayoutAttribute in newValue {
                let eventDescriptor = anEventLayoutAttribute.descriptor
                if eventDescriptor.isAllDay {
                    allDayLayoutAttributes.append(anEventLayoutAttribute)
                } else {
                    regularLayoutAttributes.append(anEventLayoutAttribute)
                }
            }
            
            recalculateEventLayout()
            prepareEventViews()
            allDayView.events = allDayLayoutAttributes.map { $0.descriptor }
            allDayView.isHidden = allDayLayoutAttributes.count == 0
            allDayView.scrollToBottom()
            
            setNeedsLayout()
            setNeedsDisplay()
        }
    }
    private var pool = ReusePool<EventView>()
    
    public var firstEvent: EventDescriptor? {
        let first = regularLayoutAttributes.sorted{$0.frame.origin.y < $1.frame.origin.y}.first
        return first?.descriptor
    }
    
    public var firstEventYPosition: CGFloat? {
        let first = regularLayoutAttributes.sorted{$0.frame.origin.y < $1.frame.origin.y}.first
        guard let firstEvent = first else {return nil}
        let firstEventPosition = firstEvent.frame.origin.y
        let beginningOfDayPosition = dateToY(date)
        return max(firstEventPosition, beginningOfDayPosition)
    }
    
    
    public func xPosition(event: EventDescriptor?, includeSidebar: Bool) -> CGFloat? {
        guard let targetEvent = event else {return nil}
        
        let rightToLeft = (UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft)
        
        var xOrigin : CGFloat = 0
        if (rightToLeft){
            xOrigin = bounds.width
        }
        if (includeSidebar == false){
            if (rightToLeft){
                xOrigin = xOrigin - timeSidebarWidth
            } else {
                xOrigin = xOrigin + timeSidebarWidth
            }
        }
        
        let totalColumnCount = delegate?.numberOfColumnsForDate(date) ?? 1
        if (totalColumnCount == 1){
            return xOrigin
        }
        
        let eventFrame = frameForDescriptor(targetEvent)
        let centerX = eventFrame.origin.x + ( eventFrame.size.width / 2 );
        let centerY = eventFrame.origin.y + ( eventFrame.size.height / 2 );
        let eventCenterPoint = CGPoint(x: centerX,
                                       y: centerY)
        
        let colIndex = columnIndexAtPoint(eventCenterPoint)
        if (colIndex == 0){
            return xOrigin
        }
        
        let colFrame = frameForColumn(columnIndex: colIndex)
        if (rightToLeft){
            return colFrame.maxX
        }
        return colFrame.minX
    }
    
    
    public func yPosition(event: EventDescriptor?) -> CGFloat? {
        guard let targetEvent = event else {return nil}
        for i in 0...regularLayoutAttributes.count{
            let eventLayoutAttributes : EventLayoutAttributes  = regularLayoutAttributes[i]
            if (eventLayoutAttributes.descriptor === targetEvent){
                let eventPosition = eventLayoutAttributes.frame.origin.y
                let beginningOfDayPosition = dateToY(date)
                return max(eventPosition, beginningOfDayPosition)
            }
        }
        return nil
    }
    
    
    public func visibleDescriptors(heightFraction: CGFloat = 1.0) -> [EventDescriptor]? {
        var fraction = heightFraction
        if (fraction > 1){
            fraction = 1.0
        }
        
        if eventViews.isEmpty { return nil}
        
        guard let enclosingView = superview else {return nil}
        
        var array = [EventDescriptor]()
        for (idx, attributes) in regularLayoutAttributes.enumerated() {
            let descriptor = attributes.descriptor
            let eventView = eventViews[idx]
            let frame = eventView.frame
            
            let visibleRect = frame.intersection(enclosingView.bounds)
            if (visibleRect.size.height > frame.size.height * fraction){
                array.append(descriptor)
            }
        }
        
        return array
    }
    
    public func visibleInterval() -> DateInterval? {
        
        guard let enclosingView = superview else {return nil}
        
        let enclosingBounds = enclosingView.convert(enclosingView.bounds, to: self)
        let visibleRect = self.bounds.intersection(enclosingBounds)
        if (visibleRect.origin.y.isNaN){
            return nil
        }
        if (visibleRect.origin.y.isInfinite){
            return nil
        }
        if (visibleRect.height.isNaN){
            return nil
        }
        if (visibleRect.height.isInfinite){
            return nil
        }
        
        
        let startDate = yToDate(visibleRect.origin.y)
        let endDate = yToDate(visibleRect.origin.y + visibleRect.size.height)
        
        let interval = DateInterval(start: startDate, end: endDate)
        
        return interval
    }
    
    
    
    private lazy var nowLine: CurrentTimeIndicator = CurrentTimeIndicator()
    
    private var allDayViewTopConstraint: NSLayoutConstraint?
    private lazy var allDayView: AllDayView = {
        let allDayView = AllDayView(frame: CGRect.zero)
        
        allDayView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(allDayView)
        
        allDayViewTopConstraint = allDayView.topAnchor.constraint(equalTo: topAnchor, constant: 0)
        allDayViewTopConstraint?.isActive = true
        
        allDayView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0).isActive = true
        allDayView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0).isActive = true
        
        return allDayView
    }()
    
    var allDayViewHeight: CGFloat {
        allDayView.bounds.height
    }
    
    var style = TimelineStyle()
    private var horizontalEventInset: CGFloat = 3
    
    public var fullHeight: CGFloat {
        style.verticalInset * 2 + style.verticalDiff * 24
    }
    
    public var calendarWidth: CGFloat {
        bounds.width - style.leadingInset
    }
    
    public private(set) var is24hClock = true {
        didSet {
            setNeedsDisplay()
        }
    }
    
    public var calendar: Calendar = Calendar.autoupdatingCurrent {
        didSet {
            eventEditingSnappingBehavior.calendar = calendar
            nowLine.calendar = calendar
            regenerateTimeStrings()
            setNeedsLayout()
        }
    }
    
    public var eventEditingSnappingBehavior: EventEditingSnappingBehavior = SnapTo15MinuteIntervals() {
        didSet {
            eventEditingSnappingBehavior.calendar = calendar
        }
    }
    
    private var times: [String] {
        is24hClock ? _24hTimes : _12hTimes
    }
    
    private lazy var _12hTimes: [String] = TimeStringsFactory(calendar).make12hStrings()
    private lazy var _24hTimes: [String] = TimeStringsFactory(calendar).make24hStrings()
    
    private func regenerateTimeStrings() {
        let factory = TimeStringsFactory(calendar)
        _12hTimes = factory.make12hStrings()
        _24hTimes = factory.make24hStrings()
    }
    
    public lazy private(set) var longPressGestureRecognizer = UILongPressGestureRecognizer(target: self,
                                                                                           action: #selector(longPress(_:)))
    
    public lazy private(set) var tapGestureRecognizer = UITapGestureRecognizer(target: self,
                                                                               action: #selector(tap(_:)))
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
        // MARK: - Initialization
    
    public init() {
        super.init(frame: .zero)
        frame.size.height = fullHeight
        configure()
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }
    
    private func configure() {
        contentScaleFactor = 1
        layer.contentsScale = 1
        contentMode = .redraw
        backgroundColor = .white
        addSubview(nowLine)
        
            // Add long press gesture recognizer
        addGestureRecognizer(longPressGestureRecognizer)
        addGestureRecognizer(tapGestureRecognizer)
    }
    
        // MARK: - Event Handling
    
    @objc private func longPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if (gestureRecognizer.state == .began) {
                // Get timeslot of gesture location
            let pressedLocation = gestureRecognizer.location(in: self)
            let colIndex = columnIndexAtPoint( pressedLocation)
            if let eventView = findEventView(at: pressedLocation) {
                let eventPoint = convert(pressedLocation, to: eventView)
                let tappedOnStatus = eventView.pointOnStatus(eventPoint)
                if (tappedOnStatus == true){
                    let config = delegate?.timelineView(self, event: eventView, menuConfigurationAtStatusPoint: eventPoint)
                    if (config != nil){
                        return
                    }
                }
                let tappedOnCornerImageIndex = eventView.pointOnCornerImageAtIndex(eventPoint)
                if (tappedOnCornerImageIndex != NSNotFound){
                    let config = delegate?.timelineView(self, event: eventView, menuConfigurationAtCornerImagePoint: eventPoint, imageIndex: tappedOnCornerImageIndex)
                    if (config != nil){
                        return
                    }
                }
                delegate?.timelineView(self, didLongPress: eventView)
            } else {
                delegate?.timelineView(self, didLongPressAt: yToDate(pressedLocation.y), columnIndex: colIndex)
            }
        }
    }
    
    @objc private func tap(_ sender: UITapGestureRecognizer) {
        let pressedLocation = sender.location(in: self)
        let colIndex = columnIndexAtPoint( pressedLocation)
        if let eventView = findEventView(at: pressedLocation) {
            let eventPoint = convert(pressedLocation, to: eventView)
            let tappedOnCornerImageIndex = eventView.pointOnCornerImageAtIndex(eventPoint)
            if (tappedOnCornerImageIndex != NSNotFound){
                delegate?.timelineView(self, didTapCornerImage: eventView, imageIndex : tappedOnCornerImageIndex)
                return
            }
            delegate?.timelineView(self, didTap: eventView)
        } else {
            delegate?.timelineView(self, didTapAt: yToDate(pressedLocation.y), columnIndex: colIndex)
        }
    }
    
    
        // MARK: - Column and Title Calculations
    
    
        // show the column titles
    private var _titleViews = [TimelineColumnTitleView]()
    
    
    private func allTitleViews() ->[TimelineColumnTitleView]{
        var array = [TimelineColumnTitleView]()
        
        guard let totalColumnCount = delegate?.numberOfColumnsForDate(date) else {
            discardTitles()
            return array
        }
        while (_titleViews.count < totalColumnCount){
            _titleViews.append(TimelineColumnTitleView())
        }
        while (_titleViews.count > totalColumnCount){
            _titleViews.last?.removeFromSuperview()
            _titleViews.removeLast()
        }
        array.append(contentsOf: _titleViews)
        return array
    }
    
    
    
    public func discardTitles() {
        for titleView in _titleViews {
            titleView.removeFromSuperview()
        }
        _titleViews.removeAll()
    }
    
    private var animationDuration : CGFloat = 0.32
    public func offsetColumnTitle(xDiff: CGFloat, yDiff: CGFloat, animated: Bool){
        if (animated == false){
            UIView.performWithoutAnimation {
                reallyOffsetColumnTitle(xDiff: xDiff, yDiff: yDiff)
            }
            return
        }
        UIView.animate(withDuration: animationDuration) {
            self.reallyOffsetColumnTitle(xDiff: xDiff, yDiff: yDiff)
        }
    }
    
    
    private func reallyOffsetColumnTitle(xDiff: CGFloat, yDiff: CGFloat){
        for titleView in allTitleViews() {
            var frame = titleView.frame
            frame.origin.x = frame.origin.x + xDiff
            frame.origin.y = frame.origin.y + yDiff
            titleView.frame = frame
        }
    }
    
    
    public func offsetColumnTitle(xFactor: CGFloat, yFactor: CGFloat, animated: Bool){
        if (animated == false){
            UIView.performWithoutAnimation {
                reallyOffsetColumnTitle(xFactor: xFactor, yFactor: yFactor)
            }
            return
        }
        UIView.animate(withDuration: animationDuration) {
            self.reallyOffsetColumnTitle(xFactor: xFactor, yFactor: yFactor)
        }
        
    }
    
    
    private func reallyOffsetColumnTitle(xFactor: CGFloat, yFactor: CGFloat){
        for titleView in allTitleViews() {
            var frame = titleView.frame
            if (xFactor.isZero == false){
                frame.origin.x = frame.origin.x * xFactor
            }
            if (yFactor.isZero == false){
                frame.origin.y = frame.origin.y * yFactor
            }
            titleView.frame = frame
        }
    }
    
    
    override public var frame: CGRect {
        get {
            return super.frame
        }
        set {
            let currentWidth = super.frame.size.width
            super.frame = newValue
            if (abs(currentWidth - newValue.size.width) > 0.1){
                layoutColumnTitles(false)
            }
            
        }
    }
    
    
    public func columnTitleTopYPoint() -> CGFloat{
        var yPoint = CGFloat.greatestFiniteMagnitude
        for titleView in allTitleViews() {
            if (yPoint > titleView.frame.origin.y){
                yPoint = titleView.frame.origin.y
            }
        }
        return yPoint
    }
    
    
    public func columnTitleGreatestHeight() -> CGFloat{
        var h = 0.0
        let allTitleViews = allTitleViews()
        for titleView in allTitleViews {
            if let index = allTitleViews.firstIndex(of: titleView){
                let title = delegate?.titleOfColumnForDate(date, columnIndex: index)
                if (title == nil){
                    continue
                }
                let trimmed = title!.trimmingCharacters(in: .whitespacesAndNewlines)
                if (trimmed.count == 0){
                    continue
                }
                
                    // add the text
                titleView.text = trimmed
                
                let columnFrame = self.frameForColumn(columnIndex: index)
                let fittingFrame = titleView.sizeThatFits(columnFrame.size)
                if (h < fittingFrame.height){
                    h = fittingFrame.height
                }
            }
        }
        
        return h
    }
    
    
    public func hideColumnTitles(_ animated : Bool) {
        if (animated == false){
            UIView.performWithoutAnimation {
                reallyHideColumnTitles()
            }
            return
        }
        UIView.animate(withDuration: animationDuration) {
            self.reallyHideColumnTitles()
        }
    }
    
    
    private func reallyHideColumnTitles() {
        var needToHide = false
        let allTitleViews = allTitleViews()
        for view in allTitleViews{
            if (view.alpha.isZero == false){
                needToHide = true
                break
            }
        }
        if (needToHide == false){
            return
        }
        for titleView in allTitleViews {
            var frame = titleView.frame
            frame.origin.y = 0
            titleView.frame = frame
            titleView.alpha = 0
        }
    }
    
    
    public func showColumnTitles(_ animated : Bool) {
        if (animated == false){
            UIView.performWithoutAnimation {
                reallyShowColumnTitles()
            }
            return
        }
        UIView.animate(withDuration: animationDuration) {
            self.reallyShowColumnTitles()
        }
    }
    
    
    public func reallyShowColumnTitles() {
        var needToShow = false
        let allTitleViews = allTitleViews()
        for view in allTitleViews {
            if (view.alpha.isZero == true){
                needToShow = true
                break
            }
        }
        if (needToShow == false){
            return
        }
        
        let viewInset : CGFloat = 8
        let topDate = visibleInterval()?.start ?? yToDate(1);
        let yPoint = dateToY(topDate) + allDayViewHeight + viewInset
        for titleView in allTitleViews{
            var frame = titleView.frame
            frame.origin.y = yPoint
            titleView.frame = frame
            titleView.alpha = 1
        }
    }
    
    public func layoutColumnTitles(_ animated : Bool) {
        if (animated == false){
            UIView.performWithoutAnimation {
                reallyLayoutColumnTitles()
            }
            return
        }
        UIView.animate(withDuration: animationDuration) {
            self.reallyLayoutColumnTitles()
        }
    }
    
    
    private func reallyLayoutColumnTitles() {
        let viewInset : CGFloat = 8
        let topDate = visibleInterval()?.start ?? yToDate(1);
        let yPoint = dateToY(topDate) + allDayViewHeight + viewInset
        
        let allTitleViews = allTitleViews()
        for titleView in allTitleViews {
            if let index = allTitleViews.firstIndex(of: titleView){
                let title = delegate?.titleOfColumnForDate(date, columnIndex: index)
                if (title == nil){
                    titleView.removeFromSuperview()
                    continue
                }
                let trimmed = title!.trimmingCharacters(in: .whitespacesAndNewlines)
                if (trimmed.count == 0){
                    titleView.removeFromSuperview()
                    continue
                }
                
                    // add a view
                titleView.text = trimmed
                if (titleView.superview != self){
                    self.addSubview(titleView)
                }
                titleView.superview?.bringSubviewToFront(titleView)
                
                let columnFrame = self.frameForColumn(columnIndex: index)
                let fittingFrame = titleView.sizeThatFits(columnFrame.size)
                
                let frame = CGRect(x: columnFrame.origin.x + viewInset,
                                   y: yPoint,
                                   width: columnFrame.width - viewInset * 2,
                                   height: fittingFrame.height)
                titleView.frame = frame
            }
        }
    }
    
    
        // maybe move this to Timeline
        // although, we need to consider the total width based on device
    private func columnIndexAtPoint(_ point : CGPoint) -> NSInteger {
        
        let totalColumnCount = delegate?.numberOfColumnsForDate(date) ?? 1
        if (totalColumnCount == 1){
            return 0
        }
        
        for colNum in 1...totalColumnCount {
            let colIndex = colNum - 1
            let colFrame = frameForColumn(columnIndex: colIndex)
            if colFrame.contains(point){
                return colIndex
            }
        }
        return 0
    }
    
    private func frameForColumn(columnIndex : NSInteger) -> CGRect {
        
        guard let totalColumnCount = delegate?.numberOfColumnsForDate(date) else {
            return CGRect(x: 0,
                          y: 0,
                          width: bounds.width,
                          height: fullHeight)
        }
        
        if (columnIndex >= totalColumnCount){
            return CGRect(x: 0,
                          y: 0,
                          width: bounds.width,
                          height: fullHeight)
        }
        
        
        var xInset = timeSidebarWidth
        if (UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft){
            
                // right to left
                // start at zero
            xInset = 0
        }
        
        
            // divide the width by totalColumn - timeline.timeSidebarWidth
        let totalWidth = bounds.width - timeSidebarWidth
        let columnWidth = totalWidth / CGFloat(totalColumnCount)
        let xPoint = columnWidth * CGFloat(columnIndex) + xInset
        
        return CGRect(x: xPoint,
                      y: 0,
                      width: columnWidth,
                      height: fullHeight)
        
    }
    
    
    public func frameForDescriptor(_ descriptor : EventDescriptor) -> CGRect {
        let eventColIndex = delegate?.columnIndexForDescriptor( descriptor,
                                                                date: date) ?? 0
        let frame = frameForColumn(columnIndex: eventColIndex)
        let startY = dateToY(descriptor.dateInterval.start)
        let endY = dateToY(descriptor.dateInterval.end)
        return CGRect(x: frame.origin.x,
                      y: startY,
                      width: frame.size.width,
                      height: endY - startY)
    }
    
    
    private func frameForClosedInterval(_ dateInterval: NSDateInterval) -> CGRect {
        
            // will frame out an area minus the timeSidebar
        let beginStart = dateToY(dateInterval.startDate);
        let endStart = dateToY(dateInterval.endDate);
        
        var xPoint = timeSidebarWidth
        if (UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft){
            
                // right to left
                // start at zero
            xPoint = 0
        }
        
        let totalWidth = bounds.width - timeSidebarWidth
        let totalHeight = endStart - beginStart
        
        return CGRect(x: xPoint,
                      y: beginStart,
                      width: totalWidth,
                      height: totalHeight)
        
    }
    
    
    private func drawClosedPattern(context: CGContext, in drawRect: CGRect)  {
        
        var closedColor = UIColor.black.withAlphaComponent(0.1)
        if #available(iOS 12.0, *) {
            let isDarkMode = (traitCollection.userInterfaceStyle == .dark)
            if (isDarkMode == true){
                closedColor = UIColor.white.withAlphaComponent(0.1)
            }
        } else {
                // Fallback on earlier versions
        }
        
        
            // left to right
            // inset width
        var eventRect = drawRect;
        if (UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft){
            
                // right to left
                // inset width by timeSidebarWidth
            eventRect = CGRect(x: drawRect.minX,
                               y: drawRect.minY,
                               width: (drawRect.width - timeSidebarWidth),
                               height: drawRect.height);
            
        } else {
            
                // left to right
                // push x by timeSidebarWidth
            eventRect = CGRect(x: (drawRect.minX + timeSidebarWidth),
                               y: drawRect.minY,
                               width: drawRect.width,
                               height: drawRect.height);
            
        }
        
            // find the closed areas
        let closedStartInterval = closedStartInterval()
        let closedStartRect = frameForClosedInterval(closedStartInterval)
        
        let closedStart = eventRect.intersection(closedStartRect)
        if (closedStart.isNull == false){
            
            context.interpolationQuality = .none
            context.saveGState()
            context.setFillColor(closedColor.cgColor)
            context.fill(closedStart)
            context.restoreGState()
            
        }
        
        let closedEndInterval = closedEndInterval()
        let closedEndRect = frameForClosedInterval(closedEndInterval)
        
        let closedEnd = eventRect.intersection(closedEndRect)
        if (closedEnd.isNull == false){
            
            context.interpolationQuality = .none
            context.saveGState()
            context.setFillColor(closedColor.cgColor)
            context.fill(closedEnd)
            context.restoreGState()
        }
        
    }
    
        // supposed to draw a pattern, but something is not working
        // I get a crash when trying to use it
        // https://www.raywenderlich.com/19164942-core-graphics-tutorial-patterns-and-playgrounds
    
        //    private func drawClosedTrianglePattern(context: CGContext, in drawRect: CGRect)  {
        //
        //        let lightColor: UIColor = .orange
        //        let darkColor: UIColor = .yellow
        //        let patternSize: CGFloat = 200
        //
        //
        //            // make thr triangle image
        //        let drawSize = CGSize(width: patternSize,
        //                              height: patternSize)
        //
        //            // make the triangle image
        //        UIGraphicsBeginImageContextWithOptions(drawSize, true, 0.0)
        //
        //            // Set the fill color for the new context
        //        darkColor.setFill()
        //        context.fill(CGRect(x: 0,
        //                            y: 0,
        //                            width: drawSize.width,
        //                            height: drawSize.height))
        //
        //        let trianglePath = UIBezierPath()
        //            // 1
        //        trianglePath.move(to: CGPoint(x: drawSize.width / 2, y: 0))
        //            // 2
        //        trianglePath.addLine(to: CGPoint(x: 0, y: drawSize.height / 2))
        //            // 3
        //        trianglePath.addLine(to: CGPoint(x: drawSize.width, y: drawSize.height / 2))
        //
        //            // 4
        //        trianglePath.move(to: CGPoint(x: 0, y: drawSize.height / 2))
        //            // 5
        //        trianglePath.addLine(to: CGPoint(x: drawSize.width / 2, y: drawSize.height))
        //            // 6
        //        trianglePath.addLine(to: CGPoint(x: 0, y: drawSize.height))
        //
        //            // 7
        //        trianglePath.move(to: CGPoint(x: drawSize.width, y: drawSize.height / 2))
        //            // 8
        //        trianglePath.addLine(to: CGPoint(x: drawSize.width / 2, y: drawSize.height))
        //            // 9
        //        trianglePath.addLine(to: CGPoint(x: drawSize.width, y: drawSize.height))
        //
        //        lightColor.setFill()
        //        trianglePath.fill()
        //
        //        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
        //            fatalError("\(#function):\(#line) Failed to get an image from current context.")
        //        }
        //        UIGraphicsEndImageContext()
        //
        //
        //            // left to right
        //            // inset width
        //        var eventRect = drawRect;
        //        if (UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft){
        //
        //                // right to left
        //                // inset width by timeSidebarWidth
        //            eventRect = CGRect(x: drawRect.minX,
        //                               y: drawRect.minY,
        //                               width: (drawRect.width - timeSidebarWidth),
        //                               height: drawRect.height);
        //
        //        } else {
        //
        //                // left to right
        //                // push x by timeSidebarWidth
        //            eventRect = CGRect(x: (drawRect.minX + timeSidebarWidth),
        //                               y: drawRect.minY,
        //                               width: drawRect.width,
        //                               height: drawRect.height);
        //
        //        }
        //
        //
        //            // find the closed areas
        //        let closedStartInterval = closedStartInterval()
        //        let closedStartRect = frameForClosedInterval(closedStartInterval);
        //
        //        let closedStart = eventRect.intersection(closedStartRect)
        //        if (closedStart.isNull == false){
        //
        //            context.interpolationQuality = .none
        //
        //            context.saveGState()
        //
        //                // draw the dark background
        //            context.setFillColor(darkColor.cgColor)
        //            context.fill(closedStart)
        //
        //                // draw the image pattern
        //            UIColor(patternImage: image).setFill()
        //            context.fill(closedStart)
        //
        //            context.restoreGState()
        //
        //        }
        //
        //        let closedEndInterval = closedEndInterval()
        //        let closedEndRect = frameForClosedInterval(closedEndInterval)
        //
        //        let closedEnd = eventRect.intersection(closedEndRect)
        //        if (closedEnd.isNull == false){
        //
        //            context.interpolationQuality = .none
        //                // draw the dark background
        //            context.setFillColor(darkColor.cgColor)
        //            context.fill(closedEnd)
        //
        //                // draw the image pattern
        //            UIColor(patternImage: image).setFill()
        //            context.fill(closedEnd)
        //
        //            context.restoreGState()
        //        }
        //
        //    }
    
    
    private func closedStartInterval() -> NSDateInterval {
        
        let startOfToday = NSCalendar.current.startOfDay(for: date)
        let endOfToday = Date(timeInterval: 86399, since: startOfToday)
        
        let openInterval = delegate?.openIntervalForDate(date) ??
        NSDateInterval.init(start: startOfToday, end: endOfToday)
        
        
        return NSDateInterval.init(start: startOfToday, end: openInterval.startDate)
    }
    
    private func closedEndInterval() -> NSDateInterval {
        
        let startOfToday = NSCalendar.current.startOfDay(for: date)
        let endOfToday = Date(timeInterval: 86399, since: startOfToday)
        
        let openInterval = delegate?.openIntervalForDate(date) ??
        NSDateInterval.init(start: startOfToday, end: endOfToday)
        
        
        return NSDateInterval.init(start: openInterval.endDate, end: endOfToday)
    }
    
    
    private func findEventView(at point: CGPoint) -> EventView? {
        for eventView in allDayView.eventViews {
            let frame = eventView.convert(eventView.bounds, to: self)
            if frame.contains(point) {
                return eventView
            }
        }
        
        for eventView in eventViews {
            let frame = eventView.frame
            if frame.contains(point) {
                return eventView
            }
        }
        return nil
    }
    
    
    /**
     Custom implementation of the hitTest method is needed for the tap gesture recognizers
     located in the AllDayView to work.
     Since the AllDayView could be outside of the Timeline's bounds, the touches to the EventViews
     are ignored.
     In the custom implementation the method is recursively invoked for all of the subviews,
     regardless of their position in relation to the Timeline's bounds.
     */
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for subview in allDayView.subviews {
            if let subSubView = subview.hitTest(convert(point, to: subview), with: event) {
                return subSubView
            }
        }
        return super.hitTest(point, with: event)
    }
    
        // MARK: - Style
    
    public func updateStyle(_ newStyle: TimelineStyle) {
        style = newStyle
        allDayView.updateStyle(style.allDayStyle)
        nowLine.updateStyle(style.timeIndicator)
        
        switch style.dateStyle {
        case .twelveHour:
            is24hClock = false
        case .twentyFourHour:
            is24hClock = true
        default:
            is24hClock = calendar.locale?.uses24hClock() ?? Locale.autoupdatingCurrent.uses24hClock()
        }
        
        backgroundColor = style.backgroundColor
        setNeedsDisplay()
    }
    
        // MARK: - Background Pattern
    
    
    
    public var accentedDate: Date?
    
    override public func draw(_ rect: CGRect) {
        super.draw(rect)
        
            // draw closed indicator
        drawClosedPattern(context: UIGraphicsGetCurrentContext()!, in: rect)
        
        
        var hourToRemoveIndex = -1
        
        var accentedHour = -1
        var accentedMinute = -1
        
        if let accentedDate = accentedDate {
            accentedHour = eventEditingSnappingBehavior.accentedHour(for: accentedDate)
            accentedMinute = eventEditingSnappingBehavior.accentedMinute(for: accentedDate)
        }
        
        if isToday {
            let minute = component(component: .minute, from: currentTime)
            let hour = component(component: .hour, from: currentTime)
            if minute > 39 {
                hourToRemoveIndex = hour + 1
            } else if minute < 21 {
                hourToRemoveIndex = hour
            }
        }
        
        let mutableParagraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        mutableParagraphStyle.lineBreakMode = .byWordWrapping
        mutableParagraphStyle.alignment = .right
        let paragraphStyle = mutableParagraphStyle.copy() as! NSParagraphStyle
        
        let attributes = [NSAttributedString.Key.paragraphStyle: paragraphStyle,
                          NSAttributedString.Key.foregroundColor: self.style.timeColor,
                          NSAttributedString.Key.font: style.font] as [NSAttributedString.Key : Any]
        
        let scale = UIScreen.main.scale
        let hourLineHeight = 1 / UIScreen.main.scale
        
        let center: CGFloat
        if Int(scale) % 2 == 0 {
            center = 1 / (scale * 2)
        } else {
            center = 0
        }
        
        let offset = 0.5 - center
        
        for (hour, time) in times.enumerated() {
            let rightToLeft = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft
            
            let hourFloat = CGFloat(hour)
            let context = UIGraphicsGetCurrentContext()
            context!.interpolationQuality = .none
            context?.saveGState()
            context?.setStrokeColor(style.separatorColor.cgColor)
            context?.setLineWidth(hourLineHeight)
            let xStart: CGFloat = {
                if rightToLeft {
                    return bounds.width - timeSidebarWidth
                } else {
                    return timeSidebarWidth
                }
            }()
            let xEnd: CGFloat = {
                if rightToLeft {
                    return 0
                } else {
                    return bounds.width
                }
            }()
            
            let totalColumnCount = delegate?.numberOfColumnsForDate(date) ?? 1
            let totalWidth = abs(xEnd - xStart)
            var eachColWidth = CGFloat(totalWidth) / CGFloat(totalColumnCount)
            eachColWidth = 1 * floor(((eachColWidth)/1)+0.5);
            
            let y = style.verticalInset + hourFloat * style.verticalDiff + offset
            context?.beginPath()
            context?.move(to: CGPoint(x: xStart, y: y))
            context?.addLine(to: CGPoint(x: xEnd, y: y))
            context?.setLineWidth(hourLineHeight / 2)
            for colNum in 1...totalColumnCount {
                let index = colNum - 1
                let verticalXStart = xStart + eachColWidth * CGFloat(index)
                context?.move(to: CGPoint(x: verticalXStart, y: y))
                context?.addLine(to: CGPoint(x: verticalXStart, y: rect.height))
            }
            context?.strokePath()
            context?.restoreGState()
            
            if hour == hourToRemoveIndex { continue }
            
            let fontSize = style.font.pointSize
            let timeRect: CGRect = {
                var x: CGFloat
                if rightToLeft {
                    x = bounds.width - timeSidebarWidth
                } else {
                    x = 2
                }
                
                return CGRect(x: x,
                              y: hourFloat * style.verticalDiff + style.verticalInset - 7,
                              width: style.leadingInset - 8,
                              height: fontSize + 2)
            }()
            
            let timeString = NSString(string: time)
            timeString.draw(in: timeRect, withAttributes: attributes)
            
            if accentedMinute == 0 {
                continue
            }
            
            if hour == accentedHour {
                
                var x: CGFloat
                if UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft {
                    x = bounds.width - (style.leadingInset + 7)
                } else {
                    x = 2
                }
                
                let timeRect = CGRect(x: x, y: hourFloat * style.verticalDiff + style.verticalInset - 7     + style.verticalDiff * (CGFloat(accentedMinute) / 60),
                                      width: style.leadingInset - 8, height: fontSize + 2)
                
                let timeString = NSString(string: ":\(accentedMinute)")
                
                timeString.draw(in: timeRect, withAttributes: attributes)
            }
        }
        
    }
    
        // MARK: - Layout
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        recalculateEventLayout()
        layoutEvents()
        layoutNowLine()
        layoutAllDayEvents()
    }
    
    private func layoutNowLine() {
        if !isToday {
            nowLine.alpha = 0
        } else {
            bringSubviewToFront(nowLine)
            nowLine.alpha = 1
            let size = CGSize(width: bounds.size.width, height: 20)
            let rect = CGRect(origin: CGPoint.zero, size: size)
            nowLine.date = currentTime
            nowLine.frame = rect
            nowLine.center.y = dateToY(currentTime)
        }
    }
    
    private func layoutEvents() {
        if eventViews.isEmpty { return }
        
        for (idx, attributes) in regularLayoutAttributes.enumerated() {
            let descriptor = attributes.descriptor
            let eventView = eventViews[idx]
            eventView.frame = attributes.frame
            
            var x: CGFloat
            if UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft {
                x = bounds.width - attributes.frame.minX - attributes.frame.width
            } else {
                x = attributes.frame.minX
            }
            
            eventView.frame = CGRect(x: x,
                                     y: attributes.frame.minY,
                                     width: attributes.frame.width - style.eventGap,
                                     height: attributes.frame.height - style.eventGap)
            eventView.updateWithDescriptor(event: descriptor)
        }
    }
    
    private func layoutAllDayEvents() {
            //add day view needs to be in front of the nowLine
        bringSubviewToFront(allDayView)
    }
    
    /**
     This will keep the allDayView as a staionary view in its superview
     
     - parameter yValue: since the superview is a scrollView, `yValue` is the
     `contentOffset.y` of the scroll view
     */
    public func offsetAllDayView(by yValue: CGFloat) {
        if let topConstraint = self.allDayViewTopConstraint {
            topConstraint.constant = yValue
            layoutIfNeeded()
        }
    }
    
    private func recalculateEventLayout() {
        
            // only non allDay events need their frames to be set
        let sortedEvents = self.regularLayoutAttributes.sorted { (attr1, attr2) -> Bool in
            let start1 = attr1.descriptor.dateInterval.start
            let start2 = attr2.descriptor.dateInterval.start
            return start1 < start2
        }
        
            // subsort by column
        var subsortedEvents = [[EventLayoutAttributes]]()
        let totalColumnCount = delegate?.numberOfColumnsForDate(date) ?? 1
        for colNum in 1...totalColumnCount {
            let colIndex = colNum - 1
            
            var colEvents = [EventLayoutAttributes]()
            for event in sortedEvents {
                let eventColIndex = delegate?.columnIndexForDescriptor( event.descriptor,
                                                                        date: date) ?? 0
                if (eventColIndex == colIndex){
                    colEvents.append(event)
                }
            }
            
            subsortedEvents.append(colEvents)
        }
        
        
        
        var groupsOfEvents = [[EventLayoutAttributes]]()
        var overlappingEvents = [EventLayoutAttributes]()
        
        for eventByColArray in subsortedEvents {
            for event in eventByColArray {
                if overlappingEvents.isEmpty {
                    overlappingEvents.append(event)
                    continue
                }
                
                let longestEvent = overlappingEvents.sorted { (attr1, attr2) -> Bool in
                    var period = attr1.descriptor.dateInterval
                    let period1 = period.end.timeIntervalSince(period.start)
                    period = attr2.descriptor.dateInterval
                    let period2 = period.end.timeIntervalSince(period.start)
                    
                    return period1 > period2
                }
                    .first!
                
                if style.eventsWillOverlap {
                    guard let earliestEvent = overlappingEvents.first?.descriptor.dateInterval.start else { continue }
                    let dateInterval = getDateInterval(date: earliestEvent)
                    if event.descriptor.dateInterval.contains(dateInterval.start) {
                        overlappingEvents.append(event)
                        continue
                    }
                } else {
                    let lastEvent = overlappingEvents.last!
                    if (longestEvent.descriptor.dateInterval.intersects(event.descriptor.dateInterval) && (longestEvent.descriptor.dateInterval.end != event.descriptor.dateInterval.start || style.eventGap <= 0.0)) ||
                        (lastEvent.descriptor.dateInterval.intersects(event.descriptor.dateInterval) && (lastEvent.descriptor.dateInterval.end != event.descriptor.dateInterval.start || style.eventGap <= 0.0)) {
                        overlappingEvents.append(event)
                        continue
                    }
                }
                groupsOfEvents.append(overlappingEvents)
                overlappingEvents = [event]
            }
        }
        
        groupsOfEvents.append(overlappingEvents)
        overlappingEvents.removeAll()
        
        for overlappingEvents in groupsOfEvents {
            let totalCount = CGFloat(overlappingEvents.count)
            for (index, event) in overlappingEvents.enumerated() {
                let eventSoloFrame = frameForDescriptor(event.descriptor)
                let sharedWidth = eventSoloFrame.size.width / totalCount
                let floatIndex = CGFloat(index)
                let x = eventSoloFrame.origin.x + floatIndex * sharedWidth
                event.frame = CGRect(x: x,
                                     y: eventSoloFrame.origin.y,
                                     width: sharedWidth,
                                     height: eventSoloFrame.size.height)
            }
        }
    }
    
    private func prepareEventViews() {
        pool.enqueue(views: eventViews)
        eventViews.removeAll()
        for _ in regularLayoutAttributes {
            let newView = pool.dequeue()
            if newView.superview == nil {
                let interaction = UIContextMenuInteraction(delegate: self)
                newView.interactions = [interaction]
                addSubview(newView)
            }
            eventViews.append(newView)
        }
        for titleView in allTitleViews() {
            titleView.superview?.bringSubviewToFront(titleView)
        }
    }
    
    public func prepareForReuse() {
        pool.enqueue(views: eventViews)
        eventViews.removeAll()
        setNeedsDisplay()
    }
    
    
    public func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        for eventView in eventViews {
            let indexOfInteraction = eventView.interactions.firstIndex(where: {$0 === interaction})
            if (indexOfInteraction != nil){
                if eventView.pointOnStatus(location){
                    return delegate?.timelineView(self, event: eventView, menuConfigurationAtStatusPoint: location)
                }
            }
            let tappedOnCornerImageIndex = eventView.pointOnCornerImageAtIndex(location)
            if (tappedOnCornerImageIndex != NSNotFound){
                return delegate?.timelineView(self, event: eventView, menuConfigurationAtCornerImagePoint: location, imageIndex: tappedOnCornerImageIndex)
            }
        }
        return nil
    }
    
    
        // MARK: - Helpers
    
    public func dateToY(_ date: Date) -> CGFloat {
        let provisionedDate = date.dateOnly(calendar: calendar)
        let timelineDate = self.date.dateOnly(calendar: calendar)
        var dayOffset: CGFloat = 0
        if provisionedDate > timelineDate {
                // Event ending the next day
            dayOffset += 1
        } else if provisionedDate < timelineDate {
                // Event starting the previous day
            dayOffset -= 1
        }
        let fullTimelineHeight = 24 * style.verticalDiff
        let hour = component(component: .hour, from: date)
        let minute = component(component: .minute, from: date)
        let hourY = CGFloat(hour) * style.verticalDiff + style.verticalInset
        let minuteY = CGFloat(minute) * style.verticalDiff / 60
        return hourY + minuteY + fullTimelineHeight * dayOffset
    }
    
    public func yToDate(_ y: CGFloat) -> Date {
        let timeValue = y - style.verticalInset
        var hour = Int(timeValue / style.verticalDiff)
        let fullHourPoints = CGFloat(hour) * style.verticalDiff
        let minuteDiff = timeValue - fullHourPoints
        let minute = Int(minuteDiff / style.verticalDiff * 60)
        var dayOffset = 0
        if hour > 23 {
            dayOffset += 1
            hour -= 24
        } else if hour < 0 {
            dayOffset -= 1
            hour += 24
        }
        let offsetDate = calendar.date(byAdding: DateComponents(day: dayOffset),
                                       to: date)!
        let newDate = calendar.date(bySettingHour: hour,
                                    minute: minute.clamped(to: 0...59),
                                    second: 0,
                                    of: offsetDate)
        return newDate!
    }
    
    private func component(component: Calendar.Component, from date: Date) -> Int {
        return calendar.component(component, from: date)
    }
    
    private func getDateInterval(date: Date) -> DateInterval {
        let earliestEventMinutes = component(component: .minute, from: date)
        let splitMinuteInterval = style.splitMinuteInterval
        let minute = component(component: .minute, from: date)
        let minuteRange = (minute / splitMinuteInterval) * splitMinuteInterval
        let beginningRange = calendar.date(byAdding: .minute, value: -(earliestEventMinutes - minuteRange), to: date)!
        let endRange = calendar.date(byAdding: .minute, value: splitMinuteInterval, to: beginningRange)!
        return DateInterval(start: beginningRange, end: endRange)
    }
}
