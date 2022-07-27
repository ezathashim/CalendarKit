import UIKit

public final class TimelineContainer: UIScrollView {
    public let timeline: TimelineView
    
        // iPhone SE is 320 points wide, 640 pixels wide
    private let minColWidth: CGFloat = 300
    
    public init(_ timeline: TimelineView) {
        self.timeline = timeline
        super.init(frame: .zero)
        self.showsHorizontalScrollIndicator = false
        self.showsVerticalScrollIndicator = false
    }
    
    @available(*, unavailable)
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        let totalColumnNumber = timeline.delegate?.numberOfColumnsForDate(timeline.date) ?? 1
        var colWidth = (bounds.width - timeline.timeSidebarWidth) / CGFloat(totalColumnNumber)
        if (colWidth < minColWidth){
            colWidth = minColWidth
        }
        let timelineWidth = timeline.timeSidebarWidth + colWidth * CGFloat(totalColumnNumber);
        
        
        timeline.frame = CGRect(x: 0,
                                y: 0,
                                width: timelineWidth,
                                height: timeline.fullHeight)
        timeline.offsetAllDayView(by: contentOffset.y)
        
        
            //adjust the scroll insets
        let allDayViewHeight = timeline.allDayViewHeight
        let bottomSafeInset: CGFloat
        if #available(iOS 11.0, *) {
            bottomSafeInset = window?.safeAreaInsets.bottom ?? 0
        } else {
            bottomSafeInset = 0
        }
        scrollIndicatorInsets = UIEdgeInsets(top: allDayViewHeight, left: 0, bottom: bottomSafeInset, right: 0)
        contentInset = UIEdgeInsets(top: allDayViewHeight, left: 0, bottom: bottomSafeInset, right: 0)
    }
    
    public func prepareForReuse() {
        timeline.prepareForReuse()
    }
    
    public func scrollToFirstEvent(animated: Bool) {
        let allDayViewHeight = timeline.allDayViewHeight
        let padding = allDayViewHeight + 8
        if let yToScroll = timeline.firstEventYPosition {
            setTimelineOffset(CGPoint(x: contentOffset.x, y: yToScroll - padding), animated: animated)
        }
    }
    
    public func scrollTo(event: EventDescriptor?, animated: Bool) {
        let targetPoint = scrollPointFor(event: event)
        if ((targetPoint.x.isNaN == false) && (targetPoint.y.isNaN == false)){
            setTimelineOffset(targetPoint, animated: animated)
        }
    }
    
    private func scrollPointFor(event: EventDescriptor?)->CGPoint {
        let allDayViewHeight = timeline.allDayViewHeight
        let padding = allDayViewHeight + 8
        let xToScroll = timeline.xPosition(event: event, includeSidebar: true) ?? contentOffset.x
        var targetPoint = CGPoint(x: CGFloat.nan, y: CGFloat.nan)
        if let yToScroll = timeline.yPosition(event: event) {
            targetPoint = CGPoint(x: xToScroll,
                                  y: yToScroll - padding)
            
        }
        return targetPoint
    }
    
    public func canScrollMoreTo(event: EventDescriptor?)->Bool {
        let targetOffset = timelineOffsetFor(event: event)
        if ((targetOffset.x.isNaN == true) && (targetOffset.y.isNaN == true)){
            return false
        }
        let xDiff = abs(contentOffset.x - targetOffset.x)
        let yDiff = abs(contentOffset.y - targetOffset.y)
        return (xDiff > 2) || (yDiff > 2)
    }
    
    public func scrollTo(hour24: Float, animated: Bool = true) {
        let percentToScroll = CGFloat(hour24 / 24)
        let yToScroll = contentSize.height * percentToScroll
        let padding: CGFloat = 8
        setTimelineOffset(CGPoint(x: contentOffset.x, y: yToScroll - padding), animated: animated)
    }
    
    public func scrollTo(hour24: Float, minute: Float, animated: Bool = true) {
        let yearComponent = self.timeline.calendar.component(.year, from: self.timeline.date)
        let monthComponent = self.timeline.calendar.component(.month, from: self.timeline.date)
        let dayComponent = self.timeline.calendar.component(.day, from: self.timeline.date)
        
        let zone = self.timeline.calendar.timeZone
        
        var newComponents = DateComponents(timeZone: zone,
                                           year: yearComponent,
                                           month: monthComponent,
                                           day: dayComponent)
        newComponents.hour = Int(hour24)
        newComponents.minute = Int(minute)
        
        guard let targetDate = self.timeline.calendar.date(from: newComponents) else {return}
        
        let allDayViewHeight = timeline.allDayViewHeight
        let padding = allDayViewHeight + 8
        let yToScroll = timeline.dateToY(targetDate)
        setTimelineOffset(CGPoint(x: contentOffset.x, y: yToScroll - padding), animated: animated)
    }
    
    public func scrollToNowTime(animated: Bool = true) {
        let nowDate = Date()
        let yearComponent = self.timeline.calendar.component(.year, from: self.timeline.date)
        let monthComponent = self.timeline.calendar.component(.month, from: self.timeline.date)
        let dayComponent = self.timeline.calendar.component(.day, from: self.timeline.date)
        let hourComponent = self.timeline.calendar.component(.hour, from: nowDate)
        let minuteComponent = self.timeline.calendar.component(.minute, from: nowDate)
        
        let zone = self.timeline.calendar.timeZone
        
        let newComponents = DateComponents(timeZone: zone,
                                           year: yearComponent,
                                           month: monthComponent,
                                           day: dayComponent,
                                           hour: hourComponent,
                                           minute: minuteComponent)
        
        guard let targetDate = self.timeline.calendar.date(from: newComponents) else {return}
        
        let allDayViewHeight = timeline.allDayViewHeight
        let padding = allDayViewHeight + 8
        let yToScroll = timeline.dateToY(targetDate)
        setTimelineOffset(CGPoint(x: contentOffset.x, y: yToScroll - padding), animated: animated)
    }
    
    private func timelineOffsetFor(event: EventDescriptor?)->CGPoint {
        let offset = scrollPointFor(event: event)
        if ((offset.x.isNaN == true) && (offset.y.isNaN == true)){
            return offset
        }
        
        let yToScroll = offset.y
        let bottomOfScrollView = contentSize.height - bounds.size.height
        let newContentY = (yToScroll < bottomOfScrollView) ? yToScroll : bottomOfScrollView
        return CGPoint(x: offset.x, y: newContentY)
    }
    
    private func setTimelineOffset(_ offset: CGPoint, animated: Bool) {
        let yToScroll = offset.y
        let bottomOfScrollView = contentSize.height - bounds.size.height
        let newContentY = (yToScroll < bottomOfScrollView) ? yToScroll : bottomOfScrollView
        setContentOffset(CGPoint(x: offset.x, y: newContentY), animated: animated)
    }
}
