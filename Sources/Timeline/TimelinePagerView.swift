import UIKit

public protocol TimelinePagerViewDelegate: AnyObject {
        // zoom height and width change to pinch gesture
    func timelinePagerDidChangeHeightScaleFactor(timelinePager: TimelinePagerView)
    func timelinePagerDidChangeWidthScaleFactor(timelinePager: TimelinePagerView)
    
    func timelinePagerDidSelectEventView(_ eventView: EventView)
    func timelinePagerDidTapCornerImageEventView(_ eventView: EventView, imageIndex: NSInteger)
    func timelinePagerDidLongPressEventView(_ eventView: EventView)
    func timelinePager(timelinePager: TimelinePagerView, didTapTimelineAt date: Date, columnIndex: NSInteger)
    func timelinePagerDidBeginDragging(timelinePager: TimelinePagerView)
    func timelinePagerDidTransitionCancel(timelinePager: TimelinePagerView)
    func timelinePager(timelinePager: TimelinePagerView, willMoveTo date: Date)
    func timelinePager(timelinePager: TimelinePagerView, didMoveTo  date: Date)
    func timelinePager(timelinePager: TimelinePagerView, didLongPressTimelineAt date: Date, columnIndex: NSInteger)
    
        // context menu
    func timelinePager(timelinePager: TimelinePagerView, event: EventView, menuConfigurationAtStatusPoint point: CGPoint) -> UIContextMenuConfiguration?
    func timelinePager(timelinePager: TimelinePagerView, event: EventView, menuConfigurationAtCornerImagePoint point: CGPoint, imageIndex : NSInteger) -> UIContextMenuConfiguration?
    
        // Editing
    func timelinePager(timelinePager: TimelinePagerView, didUpdate event: EventDescriptor)
    
        //TimelineInfo
    func openIntervalForDate(_ date: Date) -> NSDateInterval
    
        // optional dataSource API
    func sortEventLayoutByStartTimeForDate(_ date: Date)  -> Bool
    func numberOfColumnsForDate(_ date: Date)  -> NSInteger
    func titleOfColumnForDate(_ date: Date, columnIndex: NSInteger) -> NSString
    func columnIndexForDescriptor(_ descriptor: EventDescriptor, date: Date) -> NSInteger
    
}

public final class TimelinePagerView: UIView, UIGestureRecognizerDelegate, UIScrollViewDelegate, DayViewStateUpdating, UIPageViewControllerDataSource, UIPageViewControllerDelegate, TimelineViewDelegate {
    
    
    public weak var dataSource: EventDataSource?
    public weak var delegate: TimelinePagerViewDelegate?
    
    public private(set) var calendar: Calendar = Calendar.autoupdatingCurrent
    public var eventEditingSnappingBehavior: EventEditingSnappingBehavior {
        didSet {
            updateEventEditingSnappingBehavior()
        }
    }
    
    public var timelineScrollOffset: CGPoint {
            // Any view is fine as they are all synchronized
        let offset = (currentTimeline)?.container.contentOffset
        return offset ?? CGPoint()
    }
    
    private var currentTimeline: TimelineContainerController? {
        pagingViewController.viewControllers?.first as? TimelineContainerController
    }
    
    public var autoScrollToFirstEvent = false
    
    private var pagingViewController = UIPageViewController(transitionStyle: .scroll,
                                                            navigationOrientation: .horizontal,
                                                            options: nil)
    private var style = TimelineStyle()
    
    public var allowsZooming = true
    private var _heightScaleFactor : CGFloat = 2.0;
    public var heightScaleFactor: CGFloat {
        get { return _heightScaleFactor }
        set {
            var factor = newValue
            if (factor < 2.0) {
                factor = 2.0
            }
            if (factor > 10.0) {
                factor = 10.0
            }
            
                // keep 2 decimal places
            let didChange = round(factor * 100) != round(_heightScaleFactor * 100)
            
            _heightScaleFactor = round(factor * 100) / 100.0
            
                // mention the change to the delegate
            if (didChange == true){
                delegate?.timelinePagerDidChangeHeightScaleFactor(timelinePager: self)
                
                updateStyle(style)
                reloadData(completionHandler: nil)
                
            }
        }
    }
    private var _widthScaleFactor : CGFloat = 1.0;
    public var widthScaleFactor: CGFloat {
        get { return _widthScaleFactor }
        set {
            var factor = newValue
            if (factor < 0.5) {
                factor = 0.5
            }
            if (factor > 6.0) {
                factor = 6.0
            }
            
                // keep 2 decimal places
            let didChange = round(factor * 100) != round(_widthScaleFactor * 100)
            
            _widthScaleFactor = round(factor * 100) / 100.0
            
                // mention the change to the delegate
            if (didChange == true){
                delegate?.timelinePagerDidChangeWidthScaleFactor(timelinePager: self)
                
                updateWidthFactor()
            }
        }
    }
    
    private lazy var pinchGestureRecognizer = UIPinchGestureRecognizer(target: self,
                                                                       action: #selector(handlePinchGesture(_:)))
    
    
    private lazy var panGestureRecognizer = UIPanGestureRecognizer(target: self,
                                                                   action: #selector(handlePanGesture(_:)))
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer.view is EventResizeHandleView {
            return false
        }
        return true
    }
    
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == panGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        guard let pendingEvent = editedEventView else {return true}
        let eventFrame = pendingEvent.frame
        let position = panGestureRecognizer.location(in: self)
        let contains = eventFrame.contains(position)
        return contains
    }
    
    public weak var state: DayViewState? {
        willSet(newValue) {
            state?.unsubscribe(client: self)
        }
        didSet {
            state?.subscribe(client: self)
        }
    }
    
    public init(calendar: Calendar) {
        self.calendar = calendar
        self.eventEditingSnappingBehavior = SnapToMinuteIntervals(calendar)
        super.init(frame: .zero)
        configure()
    }
    
    override public init(frame: CGRect) {
        self.eventEditingSnappingBehavior = SnapToMinuteIntervals(calendar)
        super.init(frame: frame)
        configure()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        self.eventEditingSnappingBehavior = SnapToMinuteIntervals(calendar)
        super.init(coder: aDecoder)
        configure()
    }
    
    private func configure() {
            // so that the editedEventView does not draw beyond bounds during dragging
        clipsToBounds = true
        
        let viewController = configureTimelineController(date: Date())
        pagingViewController.setViewControllers([viewController], direction: .forward, animated: false, completion: nil)
        pagingViewController.dataSource = self
        pagingViewController.delegate = self
        addSubview(pagingViewController.view!)
        addGestureRecognizer(panGestureRecognizer)
        panGestureRecognizer.delegate = self
        
            // pinch
        addGestureRecognizer(pinchGestureRecognizer)
        pinchGestureRecognizer.delegate = self
        
    }
    
    
    public func updateStyle(_ newStyle: TimelineStyle) {
        if Thread.current.isMainThread{
            reallyUpdateStyle(newStyle);
            return
        }
        
        DispatchQueue.main.async {
            self.reallyUpdateStyle(newStyle)
        }
    }
    
    
    public func reallyUpdateStyle(_ newStyle: TimelineStyle) {
        style = newStyle
        style.minimumEventDurationInMinutesWhileEditing = 15;
        pagingViewController.viewControllers?.forEach({ (timelineContainer) in
            if let controller = timelineContainer as? TimelineContainerController {
                updateStyleOfTimelineContainer(controller: controller)
            }
        })
        pagingViewController.view.backgroundColor = self.style.backgroundColor
    }
    
    
    public func updateWidthFactor() {
        if Thread.current.isMainThread{
            reallyUpdateWidthFactor();
            return
        }
        
        DispatchQueue.main.async {
            self.reallyUpdateWidthFactor()
        }
    }
    
    
    public func reallyUpdateWidthFactor() {
        pagingViewController.viewControllers?.forEach({ (timelineContainer) in
            if let controller = timelineContainer as? TimelineContainerController {
                controller.container.widthScaleFactor = widthScaleFactor
            }
        })
    }
    
    
    private func updateStyleOfTimelineContainer(controller: TimelineContainerController) {
        let container = controller.container
        let timeline = controller.timeline
        var zoomedStyle = TimelineStyle();
        zoomedStyle.verticalDiff = (style.verticalDiff * heightScaleFactor)
        timeline.updateStyle(zoomedStyle)
        
        container.backgroundColor = style.backgroundColor
    }
    
    private func updateEventEditingSnappingBehavior() {
        pagingViewController.viewControllers?.forEach({ (timelineContainer) in
            if let controller = timelineContainer as? TimelineContainerController {
                controller.timeline.eventEditingSnappingBehavior = eventEditingSnappingBehavior
            }
        })
    }
    
    public func timelinePanGestureRequire(toFail gesture: UIGestureRecognizer) {
        for controller in pagingViewController.viewControllers ?? [] {
            if let controller = controller as? TimelineContainerController {
                let container = controller.container
                container.panGestureRecognizer.require(toFail: gesture)
            }
        }
    }
    
    public func scrollTo(hour24: Float, animated: Bool = true) {
            // Any view is fine as they are all synchronized
        if let controller = currentTimeline {
            controller.container.scrollTo(hour24: hour24, animated: animated)
        }
    }
    
    private func configureTimelineController(date: Date) -> TimelineContainerController {
        let controller = TimelineContainerController()
        let timeline = controller.timeline
        timeline.longPressGestureRecognizer.addTarget(self, action: #selector(timelineDidLongPress(_:)))
        timeline.delegate = self
        timeline.calendar = calendar
        timeline.eventEditingSnappingBehavior = eventEditingSnappingBehavior
        timeline.date = date.dateOnly(calendar: calendar)
        updateStyleOfTimelineContainer(controller: controller)
        controller.container.widthScaleFactor = widthScaleFactor
        controller.container.delegate = self
        updateTimeline(timeline)
        return controller
    }
    
    private var draggingVertically : Bool = true
    private var initialContentOffset = CGPoint.zero
    private var previousDraggingOffset = CGPoint.zero
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        initialContentOffset = scrollView.contentOffset
        previousDraggingOffset = scrollView.contentOffset
        
        let velocity = scrollView.panGestureRecognizer.velocity(in: scrollView.superview)
        draggingVertically = abs(velocity.x) < abs(velocity.y)
        
        if (velocity.equalTo(CGPoint.zero)){
            scrollViewDidEndScrollingAnimation(scrollView)
        }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // need to only adjust if 'isDragging'
            // since this 'scrollViewDidScroll' API is called with ANY contentOffset change
        if (scrollView.isDragging == true){
            var offset = scrollView.contentOffset
            if (draggingVertically == true){
                offset.x = initialContentOffset.x
            } else {
                offset.y = initialContentOffset.y
            }
            scrollView.contentOffset = offset
            
            previousDraggingOffset = offset
            
            let diffX = offset.x - initialContentOffset.x
            let diffY = offset.y - initialContentOffset.y
            if let event = editedEventView {
                var frame = event.frame
                frame.origin.x -= diffX
                frame.origin.y -= diffY
                event.frame = frame
                initialContentOffset = offset
            }
        }
    }
    
    public func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        if (draggingVertically == true){
        
        }
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if (decelerate == false){
            scrollViewDidEndScrollingAnimation(scrollView)
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollViewDidEndScrollingAnimation(scrollView)
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        currentTimeline?.container.timeline.layoutColumnTitles()
    }
    
    
    public func reloadData(completionHandler: (() -> Void)! = nil) {
        DispatchQueue.main.async {
            self.reallyReloadData()
            if (completionHandler != nil){
                completionHandler()
            }
        }
    }
    
    
    public func reallyReloadData() {
        pagingViewController.children.forEach({ (controller) in
            if let controller = controller as? TimelineContainerController {
                updateTimeline(controller.timeline)
                controller.timeline.layoutColumnTitles()
            }
        })
    }
    
    
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        pagingViewController.view.frame = bounds
    }
    
    private func updateTimeline(_ timeline: TimelineView) {
        guard let dataSource = dataSource else {return}
        let date = timeline.date.dateOnly(calendar: calendar)
        let events = dataSource.eventsForDate(date)
        
        let end = calendar.date(byAdding: .day, value: 1, to: date)!
        let day = DateInterval(start: date, end: end)
        let validEvents = events.filter{$0.dateInterval.intersects(day)}
        let layoutAttributes = validEvents.map(EventLayoutAttributes.init)
        
            // get column information
            // total columns
        let totalColumnCount = numberOfColumnsForDate(date)
        
            // titles
        var columnTitles = [NSString]()
        for colNum in 1...totalColumnCount {
            let colIndex = colNum - 1
            let title = titleOfColumnForDate(date, columnIndex:  colIndex)
            columnTitles.append(title)
        }
        
            // add columnIndex values to layout objects
        for eventLayout in layoutAttributes {
            let colIndex = columnIndexForDescriptor(eventLayout.descriptor, date: date)
            eventLayout.columnIndex = colIndex
        }
        
        
        timeline.loadWith(attributes: layoutAttributes, columnTitles: columnTitles)
    }
    
    public func scrollToFirstEventIfNeeded(animated: Bool) {
        if autoScrollToFirstEvent {
            if let controller = currentTimeline {
                controller.container.scrollToFirstEvent(animated: animated)
            }
        }
    }
    
    public var firstEvent: EventDescriptor? {
        if let controller = currentTimeline {
            return controller.container.timeline.firstEvent
        }
        return nil
    }
    
    public func visibleDescriptors(heightFraction: CGFloat = 1.0) -> [EventDescriptor]? {
        if let controller = currentTimeline {
            return controller.container.timeline.visibleDescriptors(heightFraction: heightFraction)
        }
        return nil
    }
    
    public func visibleInterval() -> DateInterval? {
        if let controller = currentTimeline {
            return controller.container.timeline.visibleInterval()
        }
        return nil
    }
    
    public func scrollToFirstEvent(animated: Bool) {
        if let controller = currentTimeline {
            controller.container.scrollToFirstEvent(animated: animated)
        }
    }
    
    public func scrollTo(event: EventDescriptor?, animated: Bool) {
        if let controller = currentTimeline {
            controller.container.scrollTo(event: event, animated: animated)
        }
    }
    
    public func canScrollMoreTo(event: EventDescriptor?)->Bool {
        if let controller = currentTimeline {
            return controller.container.canScrollMoreTo(event: event)
        }
        return false
    }
    
    public func scrollTo(hour24: Float, minute: Float, animated: Bool = true) {
        if let controller = currentTimeline {
            controller.container.scrollTo(hour24: hour24, minute: minute, animated: animated)
        }
    }
    
    public func scrollToNowTime(animated: Bool = true) {
        if let controller = currentTimeline {
            controller.container.scrollToNowTime(animated: animated)
        }
    }
    
    
        /// Event view with editing mode active. Can be either edited or newly created event
    private var editedEventView: EventView?
        /// The `EventDescriptor` that is being edited. It's editable copy is used by the `editedEventView`
    private var editedEvent: EventDescriptor?
    
        /// Tag of the last used resize handle
    private var resizeHandleTag: Int?
    
        /// Creates an EventView and places it on the Timeline
        /// - Parameter event: the EventDescriptor based on which an EventView will be placed on the Timeline
        /// - Parameter animated: if true, CalendarKit animates event creation
    public func create(event: EventDescriptor, animated: Bool) {
        let eventView = EventView()
        eventView.updateWithDescriptor(event: event)
        addSubview(eventView)
            // layout algo
        if let currentTimeline = currentTimeline {
            
            for handle in eventView.eventResizeHandles {
                let panGestureRecognizer = handle.panGestureRecognizer
                panGestureRecognizer.addTarget(self, action: #selector(handleResizeHandlePanGesture(_:)))
                panGestureRecognizer.cancelsTouchesInView = true
            }
            
            
            let timeline = currentTimeline.timeline
            let offsetX = currentTimeline.container.contentOffset.x
            let offsetY = currentTimeline.container.contentOffset.y
                // algo needs to be extracted to a separate object
            
            var eventFrame = timeline.frameForDescriptor(event)
            
            eventFrame.origin.x = eventFrame.origin.x - offsetX
            eventFrame.origin.y = eventFrame.origin.y - offsetY
            eventView.frame = eventFrame
            
            if animated {
                eventView.animateCreation()
            }
        }
        editedEventView = eventView
        accentDateForEditedEventView()
    }
    
        /// Puts timeline in the editing mode and highlights a single event as being edited.
        /// - Parameter event: the `EventDescriptor` to be edited. An editable copy of the `EventDescriptor` is created by calling `makeEditable()` method on the passed value
        /// - Parameter animated: if true, CalendarKit animates beginning of the editing
    public func beginEditing(event: EventDescriptor, animated: Bool = false) {
        if editedEventView == nil {
            editedEvent = event
            let editableCopy = event.makeEditable()
            create(event: editableCopy, animated: animated)
        }
    }
    
    private var prevOffset: CGPoint = .zero
    @objc func handlePanGesture(_ sender: UIPanGestureRecognizer) {
        
        if let pendingEvent = editedEventView {
            let newCoord = sender.translation(in: pendingEvent)
            if sender.state == .began {
                prevOffset = newCoord
            }
            
            let diff = CGPoint(x: newCoord.x - prevOffset.x, y: newCoord.y - prevOffset.y)
                // uncomment if you want to allow for the x to change during drag
                //pendingEvent.frame.origin.x += diff.x
            pendingEvent.frame.origin.y += diff.y
            prevOffset = newCoord
            accentDateForEditedEventView()
        }
        
        if sender.state == .ended {
            commitEditing()
        }
    }
    
    
    @objc func handlePinchGesture(_ sender: UIPinchGestureRecognizer){
        
        
        if (allowsZooming == false){
            return
        }
        
        if (editedEventView != nil){
                // do not allow zoom while editing
            return
        }
        
        if (sender.state == .began) {
            return;
        }
        
        
        
        if (sender.state == .changed) {
            
            if (sender.numberOfTouches > 1) {
                                
                switch pinchOrientation(sender) {
                    
                case .vertical:
                    var currentTimelineHeight = style.verticalInset * 2 + style.verticalDiff * 24 * heightScaleFactor
                    if (currentTimelineHeight.isZero == true){
                        currentTimelineHeight = CGFloat.leastNonzeroMagnitude
                    }
                    
                    heightScaleFactor = heightScaleFactor * sender.scale;
                    
                    let zoomedTimelineHeight = style.verticalInset * 2 + style.verticalDiff * 24 * heightScaleFactor
                    
                    let hDiffRatio = zoomedTimelineHeight/currentTimelineHeight
                    
                        // we have increased the height of the timeline
                        // keep the same relative yPoint
                    if var offset = currentTimeline?.container.contentOffset{
                        if hDiffRatio.isZero == false{
                            offset.y = offset.y * hDiffRatio
                            currentTimeline?.container.contentOffset = offset
                        }
                    }
                    
                        // reset it to 1.0 so that it linearly scales the heightScaleFactor
                    sender.scale = 1.0;
                    
                case .horizontal:
                        // horizontal
                    widthScaleFactor = widthScaleFactor * sender.scale;
                    
                        // reset it to 1.0 so that it linearly scales the widthScaleFactor
                    sender.scale = 1.0;
                    
                case .diagnonal:
                        // ignore for now
                        // reset it to 1.0 so that it linearly scales the heightScaleFactor
                    sender.scale = 1.0;
                    
                case .unknown:
                        // reset it to 1.0 so that it linearly scales the heightScaleFactor
                    sender.scale = 1.0;
                }
                
                
            }
            
            return;
        }
        
        
        if (sender.state == .ended) {
            currentTimeline?.container.timeline.layoutColumnTitles()
            
            return;
        }
        
    }
    
    enum PinchOrientation {
        case vertical, horizontal, diagnonal, unknown
    }
    
    func pinchOrientation(_ sender: UIPinchGestureRecognizer) -> PinchOrientation {
        
            // very important:
        if sender.numberOfTouches < 2 {
            print("avoided an obscure crash!!")
            return .unknown
        }
        
        let A = sender.location(ofTouch: 0, in: self)
        let B = sender.location(ofTouch: 1, in: self)
        
        let xD = abs( A.x - B.x )
        let yD = abs( A.y - B.y )
        if (xD == 0) { return .vertical }
        if (yD == 0) { return .horizontal }
        let ratio = xD / yD
            // print(ratio)
        if (ratio > 2) { return .horizontal }
        if (ratio < 0.5) { return .vertical }
        return .diagnonal
    }
    
    
    @objc func handleResizeHandlePanGesture(_ sender: UIPanGestureRecognizer) {
        if let pendingEvent = editedEventView {
            let newCoord = sender.translation(in: pendingEvent)
            if sender.state == .began {
                prevOffset = newCoord
            }
            guard let tag = sender.view?.tag else {
                return
            }
            resizeHandleTag = tag
            
            let diff = CGPoint(x: newCoord.x - prevOffset.x,
                               y: newCoord.y - prevOffset.y)
            var suggestedEventFrame = pendingEvent.frame
            
            if tag == 0 { // Top handle
                suggestedEventFrame.origin.y += diff.y
                suggestedEventFrame.size.height -= diff.y
            } else { // Bottom handle
                suggestedEventFrame.size.height += diff.y
            }
            let minimumMinutesEventDurationWhileEditing = CGFloat(style.minimumEventDurationInMinutesWhileEditing)
            let minimumEventHeight = minimumMinutesEventDurationWhileEditing * style.verticalDiff / 60
            let suggestedEventHeight = suggestedEventFrame.size.height
            
            if suggestedEventHeight > minimumEventHeight {
                pendingEvent.frame = suggestedEventFrame
                prevOffset = newCoord
                accentDateForEditedEventView(eventHeight: tag == 0 ? 0 : suggestedEventHeight)
            }
        }
        
        if sender.state == .ended {
            commitEditing()
        }
    }
    
    private func accentDateForEditedEventView(eventHeight: CGFloat = 0) {
        if let currentTimeline = currentTimeline {
            let timeline = currentTimeline.timeline
            let converted = timeline.convert(CGPoint.zero, from: editedEventView)
            var date = timeline.yToDate(converted.y + eventHeight)
            date = timeline.eventEditingSnappingBehavior.roundedDateToNearestMinutes(date, minutes: 5)
            timeline.accentedDate = date
            timeline.setNeedsDisplay()
            
            if let eventInterval = editedEvent?.dateInterval {
                let snappedInterval = DateInterval(start: date, duration: eventInterval.duration)
                editedEvent?.dateInterval = snappedInterval
            }
        }
        
    }
    
    private func commitEditing() {
        if let currentTimeline = currentTimeline {
            let timeline = currentTimeline.timeline
            timeline.accentedDate = nil
            setNeedsDisplay()
            
                // TODO: Animate cancellation
            
            if let editedEventView = editedEventView,
               let descriptor = editedEventView.descriptor {
                update(descriptor: descriptor, with: editedEventView)
                
                let ytd = yToDate(y: editedEventView.frame.origin.y,
                                  timeline: timeline)
                let snapped = timeline.eventEditingSnappingBehavior.nearestDate(to: ytd)
                let leftToRight = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .leftToRight
                let x = leftToRight ? style.leadingInset : 0
                
                let colIndex = timeline.columnIndexFor(descriptor: editedEventView.descriptor!)
                let colCorrectionX = editedEventView.frame.width * CGFloat(colIndex) - currentTimeline.container.contentOffset.x
                
                var eventFrame = editedEventView.frame
                eventFrame.origin.x = colCorrectionX + x
                eventFrame.origin.y = timeline.dateToY(snapped) - currentTimeline.container.contentOffset.y
                
                if resizeHandleTag == 0 {
                    eventFrame.size.height = timeline.dateToY(descriptor.dateInterval.end) - timeline.dateToY(snapped)
                } else if resizeHandleTag == 1 {
                    let bottomHandleYTD = yToDate(y: editedEventView.frame.origin.y + editedEventView.frame.size.height,
                                                  timeline: timeline)
                    let bottomHandleSnappedDate = timeline.eventEditingSnappingBehavior.nearestDate(to: bottomHandleYTD)
                    eventFrame.size.height = timeline.dateToY(bottomHandleSnappedDate) - timeline.dateToY(snapped)
                }
                
                func animateEventSnap() {
                    editedEventView.frame = eventFrame
                }
                
                func completionHandler(_ completion: Bool) {
                    update(descriptor: descriptor, with: editedEventView)
                    delegate?.timelinePager(timelinePager: self, didUpdate: descriptor)
                }
                
                UIView.animate(withDuration: 0.3,
                               delay: 0,
                               usingSpringWithDamping: 0.6,
                               initialSpringVelocity: 5,
                               options: [],
                               animations: animateEventSnap,
                               completion: completionHandler(_:))
            }
            
            resizeHandleTag = nil
            prevOffset = .zero
        }
    }
    
    
    public func isEventEditing() -> Bool {
        return ((editedEventView != nil) || (editedEvent != nil))
    }
    
        /// Ends editing mode
    public func endEventEditing() {
        prevOffset = .zero
        editedEventView?.eventResizeHandles.forEach{$0.panGestureRecognizer.removeTarget(self, action: nil)}
        editedEventView?.removeFromSuperview()
        editedEventView = nil
        editedEvent = nil
    }
    
    @objc private func timelineDidLongPress(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .ended {
            commitEditing()
        }
    }
    
    private func yToDate(y: CGFloat, timeline: TimelineView) -> Date {
        let point = CGPoint(x: 0, y: y)
        let converted = convert(point, to: timeline).y
        let date = timeline.yToDate(converted)
        return date
    }
    
    private func update(descriptor: EventDescriptor, with eventView: EventView) {
        guard let dateInterval = dateInterval(for: eventView) else {
            return
        }
        descriptor.dateInterval = dateInterval
    }
    
    
    private func dateInterval(for eventView: EventView) -> DateInterval? {
        if let currentTimeline = currentTimeline {
            let timeline = currentTimeline.timeline
            let eventFrame = eventView.frame
            let converted = convert(eventFrame, to: timeline)
            let beginningY = converted.minY
            let endY = converted.maxY
            let beginning = timeline.yToDate(beginningY)
            let end = timeline.yToDate(endY)
            return DateInterval(start: beginning, end: end)
        }
        return nil
    }
    
    
        // MARK: DayViewStateUpdating
    
    public func move(from oldDate: Date, to newDate: Date) {
        let oldDate = oldDate.dateOnly(calendar: calendar)
        let newDate = newDate.dateOnly(calendar: calendar)
        let newController = configureTimelineController(date: newDate)
        
        delegate?.timelinePager(timelinePager: self, willMoveTo: newDate)
        
        func completionHandler(_ completion: Bool) {
            DispatchQueue.main.async { [self] in
                    // Fix for the UIPageViewController issue: https://stackoverflow.com/questions/12939280/uipageviewcontroller-navigates-to-wrong-page-with-scroll-transition-style
                
                let leftToRight = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .leftToRight
                let direction: UIPageViewController.NavigationDirection = leftToRight ? .reverse : .forward
                
                self.pagingViewController.setViewControllers([newController],
                                                             direction: direction,
                                                             animated: false,
                                                             completion: nil)
                
                self.pagingViewController.viewControllers?.first?.view.setNeedsLayout()
                self.scrollToFirstEventIfNeeded(animated: true)
                self.delegate?.timelinePager(timelinePager: self, didMoveTo: newDate)
            }
        }
        
        if newDate < oldDate {
            let leftToRight = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .leftToRight
            let direction: UIPageViewController.NavigationDirection = leftToRight ? .reverse : .forward
            pagingViewController.setViewControllers([newController],
                                                    direction: direction,
                                                    animated: true,
                                                    completion: completionHandler(_:))
        } else if newDate > oldDate {
            let leftToRight = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .leftToRight
            let direction: UIPageViewController.NavigationDirection = leftToRight ? .forward : .reverse
            pagingViewController.setViewControllers([newController],
                                                    direction: direction,
                                                    animated: true,
                                                    completion: completionHandler(_:))
        }
    }
    
        // MARK: UIPageViewControllerDataSource
    
    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let containerController = viewController as? TimelineContainerController  else {return nil}
        let previousDate = calendar.date(byAdding: .day, value: -1, to: containerController.timeline.date)!
        let timelineContainerController = configureTimelineController(date: previousDate)
        let offset = (pageViewController.viewControllers?.first as? TimelineContainerController)?.container.contentOffset
        timelineContainerController.pendingContentOffset = offset
        return timelineContainerController
    }
    
    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let containerController = viewController as? TimelineContainerController  else {return nil}
        let nextDate = calendar.date(byAdding: .day, value: 1, to: containerController.timeline.date)!
        let timelineContainerController = configureTimelineController(date: nextDate)
        let offset = (pageViewController.viewControllers?.first as? TimelineContainerController)?.container.contentOffset
        timelineContainerController.pendingContentOffset = offset
        return timelineContainerController
    }
    
        // MARK: UIPageViewControllerDelegate
    
    public func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed else {
            delegate?.timelinePagerDidTransitionCancel(timelinePager: self)
            return
        }
        if let timelineContainerController = pageViewController.viewControllers?.first as? TimelineContainerController {
            var offset = timelineContainerController.container.contentOffset
            offset.x = 0
            UIView.animate(withDuration: 0.2, animations: {
                timelineContainerController.container.contentOffset = offset
            }, completion: nil)
            
            
            let selectedDate = timelineContainerController.timeline.date
            delegate?.timelinePager(timelinePager: self, willMoveTo: selectedDate)
            state?.client(client: self, didMoveTo: selectedDate)
            scrollToFirstEventIfNeeded(animated: true)
            delegate?.timelinePager(timelinePager: self, didMoveTo: selectedDate)
        }
    }
    
    public func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        delegate?.timelinePagerDidBeginDragging(timelinePager: self)
    }
    
        // MARK: TimelineViewDelegate
    
    public func timelineView(_ timelineView: TimelineView, didTapAt date: Date, columnIndex: NSInteger){
        delegate?.timelinePager(timelinePager: self, didTapTimelineAt: date, columnIndex: columnIndex)
    }
    
    public func timelineView(_ timelineView: TimelineView, didLongPressAt date: Date, columnIndex: NSInteger){
        delegate?.timelinePager(timelinePager: self, didLongPressTimelineAt: date, columnIndex: columnIndex)
    }
    
    
    public func timelineView(_ timelineView: TimelineView, didTap event: EventView) {
        delegate?.timelinePagerDidSelectEventView(event)
    }
    
    public func timelineView(_ timelineView: TimelineView, didTapCornerImage event: EventView, imageIndex : NSInteger) {
        delegate?.timelinePagerDidTapCornerImageEventView(event, imageIndex: imageIndex)
    }

    public func timelineView(_ timelineView: TimelineView, event: EventView, menuConfigurationAtStatusPoint point: CGPoint) -> UIContextMenuConfiguration? {
        return delegate?.timelinePager(timelinePager: self, event: event, menuConfigurationAtStatusPoint: point)
    }
    
    public func timelineView(_ timelineView: TimelineView, event: EventView, menuConfigurationAtCornerImagePoint point: CGPoint, imageIndex : NSInteger) -> UIContextMenuConfiguration? {
        return delegate?.timelinePager(timelinePager: self, event: event, menuConfigurationAtCornerImagePoint: point, imageIndex : imageIndex)
    }
    
    public func timelineView(_ timelineView: TimelineView, didLongPress event: EventView) {
        delegate?.timelinePagerDidLongPressEventView(event)
    }
    
    public func openIntervalForDate(_ date: Date) -> NSDateInterval {
        
        let startOfToday = NSCalendar.current.startOfDay(for: date)
        let endOfToday = Date(timeInterval: 86399, since: startOfToday)
        
        let allDayInterval = NSDateInterval.init(start: startOfToday, end: endOfToday)
        
        return delegate?.openIntervalForDate( date) ?? allDayInterval
    }
    
    
        // MARK: TimelineDelegate Columns
    public func sortEventLayoutByStartTimeForDate(_ date: Date)  -> Bool? {
        return delegate?.sortEventLayoutByStartTimeForDate(date) ?? true
    }
    
    public func numberOfColumnsForDate(_ date: Date) -> NSInteger {
        guard var columnNumber = delegate?.numberOfColumnsForDate(date) else {
            return 1
        }
        if (columnNumber < 1){
            columnNumber = 1
        }
        return columnNumber
    }
    
    
    public func titleOfColumnForDate(_ date: Date, columnIndex: NSInteger) -> NSString {
        let title = delegate?.titleOfColumnForDate(date,
                                                   columnIndex: columnIndex) ?? ""
        return title
    }
    
    
    public func columnIndexForDescriptor(_ descriptor: EventDescriptor, date: Date) -> NSInteger {
        guard let index = delegate?.columnIndexForDescriptor(descriptor, date: date) else {
            return 0
        }
        if (index < 0){
            return 0
        }
        let numberOfColumns = numberOfColumnsForDate(date)
        if (index >= numberOfColumns){
            return 0
        }
        return index
    }
    
}
