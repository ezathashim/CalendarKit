import UIKit

@objc open class DayViewController: UIViewController, EventDataSource, DayViewDelegate {
  @objc public lazy var dayView: DayView = DayView()
  @objc public var dataSource: EventDataSource? {
    get {
      dayView.dataSource
    }
    set(value) {
      dayView.dataSource = value
    }
  }

  @objc public var delegate: DayViewDelegate? {
    get {
      dayView.delegate
    }
    set(value) {
      dayView.delegate = value
    }
  }

  public var calendar = Calendar.autoupdatingCurrent {
    didSet {
      dayView.calendar = calendar
    }
  }
  
  public var eventEditingSnappingBehavior: EventEditingSnappingBehavior {
    get {
      dayView.eventEditingSnappingBehavior
    }
    set {
      dayView.eventEditingSnappingBehavior = newValue
    }
  }

  open override func loadView() {
    view = dayView
  }

  override open func viewDidLoad() {
    super.viewDidLoad()
    edgesForExtendedLayout = []
    view.tintColor = SystemColors.systemRed
    dataSource = self
    delegate = self
    dayView.reloadData()

    let sizeClass = traitCollection.horizontalSizeClass
    configureDayViewLayoutForHorizontalSizeClass(sizeClass)
  }

  open override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    dayView.scrollToFirstEventIfNeeded()
  }

  open override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
    super.willTransition(to: newCollection, with: coordinator)
    configureDayViewLayoutForHorizontalSizeClass(newCollection.horizontalSizeClass)
  }

  open func configureDayViewLayoutForHorizontalSizeClass(_ sizeClass: UIUserInterfaceSizeClass) {
    dayView.transitionToHorizontalSizeClass(sizeClass)
  }
  
  // MARK: - CalendarKit API
  
  @objc open func move(to date: Date) {
    dayView.move(to: date)
  }

  @objc open func reloadData() {
    dayView.reloadData()
  }

  open func updateStyle(_ newStyle: CalendarStyle) {
    dayView.updateStyle(newStyle)
  }

  open func eventsForDate(_ date: Date) -> [EventDescriptor] {
    return [Event]()
  }

  // MARK: - DayViewDelegate

    
  open func dayViewDidChangeHeightScaleFactor(dayView: DayView) {
  }
    
  open func dayViewDidSelectEventView(_ eventView: EventView) {
  }

  open func dayViewDidLongPressEventView(_ eventView: EventView) {
  }

  open func dayView(dayView: DayView, didTapTimelineAt date: Date) {
  }
  
  open func dayViewDidBeginDragging(dayView: DayView) { 
  }
  
  open func dayViewDidTransitionCancel(dayView: DayView) {
  }

  open func dayView(dayView: DayView, willMoveTo date: Date) {
  }

  open func dayView(dayView: DayView, didMoveTo date: Date) {
  }

  open func dayView(dayView: DayView, didLongPressTimelineAt date: Date) {
  }

  open func dayView(dayView: DayView, didUpdate event: EventDescriptor) {
  }
    
  open func openIntervalForDate(_ date: Date) -> NSDateInterval {
        
      let startOfToday = NSCalendar.current.startOfDay(for: date)
      let endOfToday = Date(timeInterval: 86399, since: startOfToday)
        
      let allDayInterval = NSDateInterval.init(start: startOfToday, end: endOfToday)
        
      return delegate?.openIntervalForDate( date) ?? allDayInterval
  }
  
  // MARK: - Editing
  
 @objc open func create(event: EventDescriptor, animated: Bool = false) {
    dayView.create(event: event, animated: animated)
  }

  @objc open func beginEditing(event: EventDescriptor, animated: Bool = false) {
    dayView.beginEditing(event: event, animated: animated)
  }
  
  @objc open func endEventEditing() {
    dayView.endEventEditing()
  }
    
}
