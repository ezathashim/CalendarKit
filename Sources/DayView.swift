import UIKit

@objc public protocol DayViewDelegate: AnyObject {
    func dayViewDidChangeHeightScaleFactor(dayView: DayView)
    func dayViewDidChangeWidthScaleFactor(dayView: DayView)
    func dayViewDidSelectEventView(_ eventView: EventView)
    @objc optional func dayViewDidTapCornerImageEventView(_ eventView: EventView, imageIndex : NSInteger)
    func dayViewDidLongPressEventView(_ eventView: EventView)
    func dayView(dayView: DayView, didTapTimelineAt date: Date)
    func dayView(dayView: DayView, didLongPressTimelineAt date: Date)
    func dayViewDidBeginDragging(dayView: DayView)
    func dayViewDidTransitionCancel(dayView: DayView)
    func dayView(dayView: DayView, willMoveTo date: Date)
    func dayView(dayView: DayView, didMoveTo  date: Date)
    func dayView(dayView: DayView, didUpdate event: EventDescriptor)
    func openIntervalForDate(_ date: Date) -> NSDateInterval
    
        // optional dataSource API
    @objc optional func sortEventLayoutByStartTimeForDate(_ date: Date)  -> Bool
    @objc optional func numberOfColumnsForDate(_ date: Date) -> NSInteger
    @objc optional func titleOfColumnForDate(_ date: Date, columnIndex: NSInteger) -> NSString
    @objc optional func columnIndexForDescriptor(_ descriptor: EventDescriptor, date: Date) -> NSInteger
    
        // will preferentially call these instead of the non-optional variants above without columnIndex
    @objc optional func dayView(dayView: DayView, didTapTimelineAt date: Date, columnIndex : NSInteger)
    @objc optional func dayView(dayView: DayView, didLongPressTimelineAt date: Date, columnIndex : NSInteger)
    
        // will show context menu when status is long-pressed
    @objc optional func statusMenuConfiguration(forEvent: EventView) -> UIContextMenuConfiguration?
    @objc optional func cornerImageMenuConfiguration(forEvent: EventView, imageIndex : NSInteger) -> UIContextMenuConfiguration?
}

public class DayView: UIView, TimelinePagerViewDelegate {
    public weak var dataSource: EventDataSource? {
        get {
            timelinePagerView.dataSource
        }
        set(value) {
            timelinePagerView.dataSource = value
        }
    }
    
    public weak var delegate: DayViewDelegate?
    
        /// Hides or shows header view
    public var isHeaderViewVisible = true {
        didSet {
            headerHeight = isHeaderViewVisible ? DayView.headerVisibleHeight : 0
            dayHeaderView.isHidden = !isHeaderViewVisible
            setNeedsLayout()
            configureLayout()
        }
    }
    
    public var timelineScrollOffset: CGPoint {
        timelinePagerView.timelineScrollOffset
    }
    
    private static let headerVisibleHeight: CGFloat = 88
    public var headerHeight: CGFloat = headerVisibleHeight
    
    @objc public var autoScrollToFirstEvent: Bool {
        get {
            timelinePagerView.autoScrollToFirstEvent
        }
        set (value) {
            timelinePagerView.autoScrollToFirstEvent = value
        }
    }
    
    public let dayHeaderView: DayHeaderView
    public let timelinePagerView: TimelinePagerView
    
    @objc public var heightScaleFactor: CGFloat{
        set { timelinePagerView.heightScaleFactor = newValue}
        get { timelinePagerView.heightScaleFactor }
    }
    
    @objc public var widthScaleFactor: CGFloat{
        set { timelinePagerView.widthScaleFactor = newValue}
        get { timelinePagerView.widthScaleFactor }
    }
    
    public var state: DayViewState? {
        didSet {
            dayHeaderView.state = state
            timelinePagerView.state = state
        }
    }
    
    public var calendar: Calendar = Calendar.autoupdatingCurrent
    
    public var eventEditingSnappingBehavior: EventEditingSnappingBehavior {
        get {
            timelinePagerView.eventEditingSnappingBehavior
        }
        set {
            timelinePagerView.eventEditingSnappingBehavior = newValue
        }
    }
    
    private var style = CalendarStyle()
    
    public init(calendar: Calendar = Calendar.autoupdatingCurrent) {
        self.calendar = calendar
        self.dayHeaderView = DayHeaderView(calendar: calendar)
        self.timelinePagerView = TimelinePagerView(calendar: calendar)
        super.init(frame: .zero)
        configure()
    }
    
    override public init(frame: CGRect) {
        self.dayHeaderView = DayHeaderView(calendar: calendar)
        self.timelinePagerView = TimelinePagerView(calendar: calendar)
        super.init(frame: frame)
        configure()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        self.dayHeaderView = DayHeaderView(calendar: calendar)
        self.timelinePagerView = TimelinePagerView(calendar: calendar)
        super.init(coder: aDecoder)
        configure()
    }
    
    private func configure() {
        addSubview(timelinePagerView)
        addSubview(dayHeaderView)
        configureLayout()
        timelinePagerView.delegate = self
        
        if state == nil {
            let newState = DayViewState(date: Date(), calendar: calendar)
            newState.move(to: Date())
            state = newState
        }
    }
    
    private func configureLayout() {
        if #available(iOS 11.0, *) {
            dayHeaderView.translatesAutoresizingMaskIntoConstraints = false
            timelinePagerView.translatesAutoresizingMaskIntoConstraints = false
            
            dayHeaderView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor).isActive = true
            dayHeaderView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor).isActive = true
            dayHeaderView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor).isActive = true
            let heightConstraint = dayHeaderView.heightAnchor.constraint(equalToConstant: headerHeight)
            heightConstraint.priority = .defaultLow
            heightConstraint.isActive = true
            
            timelinePagerView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor).isActive = true
            timelinePagerView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor).isActive = true
            timelinePagerView.topAnchor.constraint(equalTo: dayHeaderView.bottomAnchor).isActive = true
            timelinePagerView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        }
    }
    
    public func updateStyle(_ newStyle: CalendarStyle) {
        style = newStyle
        dayHeaderView.updateStyle(style.header)
        timelinePagerView.updateStyle(style.timeline)
    }
    
    public func updateSnappingBehavior(_ eventEditingSnappingBehavior: EventEditingSnappingBehavior) {
        timelinePagerView.eventEditingSnappingBehavior = eventEditingSnappingBehavior
    }
    
    public func timelinePanGestureRequire(toFail gesture: UIGestureRecognizer) {
        timelinePagerView.timelinePanGestureRequire(toFail: gesture)
    }
    
    @objc public func scrollTo(hour24: Float, animated: Bool = true) {
        timelinePagerView.scrollTo(hour24: hour24, animated: animated)
    }
    
    
    @objc public func scrollToFirstEventIfNeeded(animated: Bool = true) {
        timelinePagerView.scrollToFirstEventIfNeeded(animated: animated)
    }
    
    @objc public func scrollToFirstEvent(animated: Bool = true) {
        timelinePagerView.scrollToFirstEvent(animated: animated)
    }
    
    @objc public var firstEvent : EventDescriptor? {
        return timelinePagerView.firstEvent
    }
    
    @objc public func visibleDescriptors(heightFraction: CGFloat = 1.0) -> [EventDescriptor]? {
        return timelinePagerView.visibleDescriptors(heightFraction: heightFraction)
    }
    
    @objc public func visibleInterval() -> DateInterval? {
        return timelinePagerView.visibleInterval()
    }
    
    @objc public func scrollTo(event: EventDescriptor?, animated: Bool) {
        timelinePagerView.scrollTo(event: event, animated: animated)
    }
    
    @objc public func canScrollMoreTo(event: EventDescriptor?)->Bool {
        return timelinePagerView.canScrollMoreTo(event: event)
    }
    
    @objc public func scrollTo(hour24: Float, minute: Float, animated: Bool = true) {
        timelinePagerView.scrollTo(hour24: hour24, minute: minute, animated: animated)
    }
    
    @objc public func scrollToNowTime(animated: Bool = true) {
        timelinePagerView.scrollToNowTime(animated: animated)
    }
    
    public func reloadData(completionHandler: (() -> Void)! = nil) {
        timelinePagerView.reloadData(completionHandler: completionHandler)
    }
    
    @objc public func move(to date: Date) {
        state?.move(to: date)
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        if #available(iOS 11, *) {} else {
            dayHeaderView.frame = CGRect(origin: CGPoint(x: 0, y: layoutMargins.top),
                                         size: CGSize(width: bounds.width, height: headerHeight))
            let timelinePagerHeight = bounds.height - dayHeaderView.frame.maxY
            timelinePagerView.frame = CGRect(origin: CGPoint(x: 0, y: dayHeaderView.frame.maxY),
                                             size: CGSize(width: bounds.width, height: timelinePagerHeight))
        }
    }
    
    public func transitionToHorizontalSizeClass(_ sizeClass: UIUserInterfaceSizeClass) {
        dayHeaderView.transitionToHorizontalSizeClass(sizeClass)
        updateStyle(style)
    }
    
    public func create(event: EventDescriptor, animated: Bool = false) {
        timelinePagerView.create(event: event, animated: animated)
    }
    
    public func beginEditing(event: EventDescriptor, animated: Bool = false) {
        timelinePagerView.beginEditing(event: event, animated: animated)
    }
    
    public func isEventEditing() -> Bool {
        return timelinePagerView.isEventEditing()
    }
    
    public func endEventEditing() {
        timelinePagerView.endEventEditing()
    }
    
        // MARK: TimelinePagerViewDelegate
    
    
    public func timelinePagerDidChangeHeightScaleFactor(timelinePager: TimelinePagerView) {
        delegate?.dayViewDidChangeHeightScaleFactor(dayView: self)
    }
    
    public func timelinePagerDidChangeWidthScaleFactor(timelinePager: TimelinePagerView) {
        delegate?.dayViewDidChangeWidthScaleFactor(dayView: self)
    }
    
    public func timelinePagerDidSelectEventView(_ eventView: EventView) {
        delegate?.dayViewDidSelectEventView(eventView)
    }
    
    public func timelinePagerDidTapCornerImageEventView(_ eventView: EventView, imageIndex : NSInteger) {
        delegate?.dayViewDidTapCornerImageEventView?(eventView, imageIndex: imageIndex) ?? delegate?.dayViewDidSelectEventView(eventView)
    }
    public func timelinePager(timelinePager: TimelinePagerView, event: EventView, menuConfigurationAtStatusPoint point: CGPoint) -> UIContextMenuConfiguration? {
        return delegate?.statusMenuConfiguration?(forEvent: event)
    }
    public func timelinePager(timelinePager: TimelinePagerView, event: EventView, menuConfigurationAtCornerImagePoint point: CGPoint, imageIndex : NSInteger) -> UIContextMenuConfiguration? {
        return delegate?.cornerImageMenuConfiguration?(forEvent: event, imageIndex: imageIndex)
    }
    public func timelinePagerDidLongPressEventView(_ eventView: EventView) {
        delegate?.dayViewDidLongPressEventView(eventView)
    }
    public func timelinePagerDidBeginDragging(timelinePager: TimelinePagerView) {
        delegate?.dayViewDidBeginDragging(dayView: self)
    }
    public func timelinePagerDidTransitionCancel(timelinePager: TimelinePagerView) {
        delegate?.dayViewDidTransitionCancel(dayView: self)
    }
    public func timelinePager(timelinePager: TimelinePagerView, willMoveTo date: Date) {
        delegate?.dayView(dayView: self, willMoveTo: date)
    }
    public func timelinePager(timelinePager: TimelinePagerView, didMoveTo  date: Date) {
        delegate?.dayView(dayView: self, didMoveTo: date)
    }
    
    public func timelinePager(timelinePager: TimelinePagerView, didLongPressTimelineAt date: Date, columnIndex: NSInteger){
        delegate?.dayView?(dayView: self, didLongPressTimelineAt: date, columnIndex: columnIndex) ?? delegate?.dayView(dayView: self, didLongPressTimelineAt: date)
    }
    public func timelinePager(timelinePager: TimelinePagerView, didTapTimelineAt date: Date, columnIndex: NSInteger) {
        delegate?.dayView?(dayView: self, didTapTimelineAt: date, columnIndex: columnIndex) ?? delegate?.dayView(dayView: self, didTapTimelineAt: date)
    }
    public func timelinePager(timelinePager: TimelinePagerView, didUpdate event: EventDescriptor) {
        delegate?.dayView(dayView: self, didUpdate: event)
    }
    
    public func openIntervalForDate(_ date: Date) -> NSDateInterval {
        
        let startOfToday = NSCalendar.current.startOfDay(for: date)
        let endOfToday = Date(timeInterval: 86399, since: startOfToday)
        
        let allDayInterval = NSDateInterval.init(start: startOfToday, end: endOfToday)
        
        return delegate?.openIntervalForDate( date) ?? allDayInterval
    }
    
    
        // optional API
    public func sortEventLayoutByStartTimeForDate(_ date: Date)  -> Bool {
        return delegate?.sortEventLayoutByStartTimeForDate?(date) ?? true
    }

    
    public func numberOfColumnsForDate(_ date: Date) -> NSInteger {
        guard var columnNumber = delegate?.numberOfColumnsForDate?(date) else {
            return 1
        }
        if (columnNumber < 1){
            columnNumber = 1
        }
        return columnNumber
    }
    
    
    public func titleOfColumnForDate(_ date: Date, columnIndex: NSInteger) -> NSString {
        guard let title = delegate?.titleOfColumnForDate?(date, columnIndex: columnIndex) else {
            return ""
        }
        return title
    }
    
    
    public func columnIndexForDescriptor(_ descriptor: EventDescriptor, date: Date) -> NSInteger {
        guard let index = delegate?.columnIndexForDescriptor?(descriptor, date: date) else {
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
