import UIKit

public protocol TimelinePagerViewDelegate: AnyObject {
        // zoom height change to pinch gesture
    func timelinePagerDidChangeHeightScaleFactor(timelinePager: TimelinePagerView)
    
    func timelinePagerDidSelectEventView(_ eventView: EventView)
    func timelinePagerDidLongPressEventView(_ eventView: EventView)
    func timelinePager(timelinePager: TimelinePagerView, didTapTimelineAt date: Date)
    func timelinePagerDidBeginDragging(timelinePager: TimelinePagerView)
    func timelinePagerDidTransitionCancel(timelinePager: TimelinePagerView)
    func timelinePager(timelinePager: TimelinePagerView, willMoveTo date: Date)
    func timelinePager(timelinePager: TimelinePagerView, didMoveTo  date: Date)
    func timelinePager(timelinePager: TimelinePagerView, didLongPressTimelineAt date: Date)
    
        // Editing
    func timelinePager(timelinePager: TimelinePagerView, didUpdate event: EventDescriptor)
    
        //TimelineInfo
    func openIntervalForDate(_ date: Date) -> NSDateInterval
    
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
            _heightScaleFactor = factor
            
                // mention the change to the delegate
            delegate?.timelinePagerDidChangeHeightScaleFactor(timelinePager: self)
            
            updateStyle(style)
            reloadData()
            
        }
    }
    
    public var pinchGestureIsVertical = false
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
        self.eventEditingSnappingBehavior = SnapTo15MinuteIntervals(calendar)
        super.init(frame: .zero)
        configure()
    }
    
    override public init(frame: CGRect) {
        self.eventEditingSnappingBehavior = SnapTo15MinuteIntervals(calendar)
        super.init(frame: frame)
        configure()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        self.eventEditingSnappingBehavior = SnapTo15MinuteIntervals(calendar)
        super.init(coder: aDecoder)
        configure()
    }
    
    private func configure() {
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
        
        DispatchQueue.main.async {
            self.style = newStyle
            self.style.minimumEventDurationInMinutesWhileEditing = 15;
            self.pagingViewController.viewControllers?.forEach({ (timelineContainer) in
                if let controller = timelineContainer as? TimelineContainerController {
                    self.updateStyleOfTimelineContainer(controller: controller)
                }
            })
            self.pagingViewController.view.backgroundColor = self.style.backgroundColor
        }
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
        updateStyleOfTimelineContainer(controller: controller)
        let timeline = controller.timeline
        timeline.longPressGestureRecognizer.addTarget(self, action: #selector(timelineDidLongPress(_:)))
        timeline.delegate = self
        timeline.calendar = calendar
        timeline.eventEditingSnappingBehavior = eventEditingSnappingBehavior
        timeline.date = date.dateOnly(calendar: calendar)
        controller.container.delegate = self
        updateTimeline(timeline)
        return controller
    }
    
    private var initialContentOffset = CGPoint.zero
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        initialContentOffset = scrollView.contentOffset
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset
        let diff = offset.y - initialContentOffset.y
        if let event = editedEventView {
            var frame = event.frame
            frame.origin.y -= diff
            event.frame = frame
            initialContentOffset = offset
        }
    }
    
    public func reloadData() {
        DispatchQueue.main.async {
            self.pagingViewController.children.forEach({ (controller) in
                if let controller = controller as? TimelineContainerController {
                    self.updateTimeline(controller.timeline)
                }
            })
        }
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
        timeline.layoutAttributes = validEvents.map(EventLayoutAttributes.init)
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
            let offset = currentTimeline.container.contentOffset.y
                // algo needs to be extracted to a separate object
            let yStart = timeline.dateToY(event.dateInterval.start) - offset
            let yEnd = timeline.dateToY(event.dateInterval.end) - offset
            
            
            let rightToLeft = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft
            let x = rightToLeft ? 0 : timeline.style.leadingInset
            let newRect = CGRect(x: x,
                                 y: yStart,
                                 width: timeline.calendarWidth,
                                 height: yEnd - yStart)
            eventView.frame = newRect
            
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
            pendingEvent.frame.origin.x += diff.x
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
            return;
        }
        
        if (sender.state == .began) {
            
                // determine if mostly horizontal or vertical
                // http://stackoverflow.com/questions/9064760/can-i-use-uipinchgesturerecognizers-to-distinguish-between-horizontal-and-vertic
            
            
                // figure out if vertical
            let touch0: CGPoint = sender.location(ofTouch: 0, in: self)
            let touch1: CGPoint = sender.location(ofTouch: 1, in: self)
            
            let tangent : CGFloat = abs((touch1.y - touch0.y) / (touch1.x - touch0.x));
            
            pinchGestureIsVertical = true
            
            if (tangent <= 0.2679491924) {
                    // 15 degrees
                    // NSLog(@"Horizontal");
                pinchGestureIsVertical = false
                
            }
            
            if (tangent >= 3.7320508076) {
                    // 75 degrees
                    // NSLog(@"Vertical");
                    // do nothing and just default to vertical
                
            }
            
            
            return;
        }
        
        
        
        if (sender.state == .changed) {
            
            if (sender.numberOfTouches > 1) {
                
                if (pinchGestureIsVertical) {
                    
                    
                    let currentTimelineHeight = 24 * style.verticalDiff * heightScaleFactor;
                    
                    heightScaleFactor = heightScaleFactor * sender.scale;
                    
                    let zoomedTimelineHeight = 24 * style.verticalDiff * heightScaleFactor;
                    
                    
                        // need to scroll while pinching
                    guard let container = currentTimeline?.container else {
                        sender.scale = 1.0;
                        return
                    }
                    
                    var scrollBounds = container.bounds
                        // we have increased the height of the timeline
                        // the bounds y will increase by 0.5 of this height change
                    let heightDiff = (zoomedTimelineHeight - currentTimelineHeight)
                    var yZoomed = scrollBounds.origin.y + (heightDiff / 2)
                    if (yZoomed < 0){
                        yZoomed = 0
                    }
                    scrollBounds.origin.y = round(yZoomed)
                    container.bounds = scrollBounds
                    
                    
                        // reset it to 1.0 so that it linearly scales the heightScaleFactor
                    sender.scale = 1.0;
                    
                    
                } else {
                    
                        // maybe width should only be adjusted on .ended
                        // need to try it out once we figure out how to adjust the layout elements
                        // only useful when we have mulitple columns working
                        //print("Adjust column width in response to pinch gesture")
                    
                }
                
                
            }
            
            return;
        }
        
        
        if (sender.state == .ended) {
            
                // TODO
                // tell the delegate that the heightScaleFactor has changed
            
            return;
        }
        
        
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
            let date = timeline.yToDate(converted.y + eventHeight)
            timeline.accentedDate = date
            timeline.setNeedsDisplay()
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
                
                var eventFrame = editedEventView.frame
                eventFrame.origin.x = x
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
        if let currentTimeline = currentTimeline {
            let timeline = currentTimeline.timeline
            let eventFrame = eventView.frame
            let converted = convert(eventFrame, to: timeline)
            let beginningY = converted.minY
            let endY = converted.maxY
            let beginning = timeline.yToDate(beginningY)
            let end = timeline.yToDate(endY)
            descriptor.dateInterval = DateInterval(start: beginning, end: end)
        }
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
    
    public func timelineView(_ timelineView: TimelineView, didTapAt date: Date) {
        delegate?.timelinePager(timelinePager: self, didTapTimelineAt: date)
    }
    
    public func timelineView(_ timelineView: TimelineView, didLongPressAt date: Date) {
        delegate?.timelinePager(timelinePager: self, didLongPressTimelineAt: date)
    }
    
    public func timelineView(_ timelineView: TimelineView, didTap event: EventView) {
        delegate?.timelinePagerDidSelectEventView(event)
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
}
