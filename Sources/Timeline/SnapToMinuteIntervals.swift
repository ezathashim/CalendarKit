import Foundation

public enum MinuteInterval: Int {
    case minutes_5 = 5
    case minutes_10 = 10
    case minutes_15 = 15
    case minutes_20 = 20
    case minutes_25 = 25
    case minutes_30 = 30
}


public struct SnapToMinuteIntervals: EventEditingSnappingBehavior {
  public var calendar = Calendar.autoupdatingCurrent
  public var interval : MinuteInterval = .minutes_5
  private let nearestMinutes : NSInteger = 5
    
  public init(_ calendar: Calendar = Calendar.autoupdatingCurrent) {
    self.calendar = calendar
  }

  public func nearestDate(to date: Date) -> Date {
    let rounded = roundedDateToNearestMinutes(date, minutes: nearestMinutes)
    let unit: Double = Double(interval.rawValue / 2)
    var accentedHour = Int(self.accentedHour(for: rounded))
    let minute = Double(component(.minute, from: rounded))
    if (60 - unit)...59 ~= minute {
      accentedHour += 1
    }

    var dayOffset = 0
    if accentedHour > 23 {
      accentedHour -= 24
      dayOffset += 1
    } else if accentedHour < 0 {
      accentedHour += 24
      dayOffset -= 1
    }
    
    let day = calendar.date(byAdding: DateComponents(day: dayOffset), to: rounded)!
    return calendar.date(bySettingHour: accentedHour,
                                minute: accentedMinute(for: rounded),
                                second: 0,
                                of: day)!
        
  }

  public func accentedHour(for date: Date) -> Int {
    Int(component(.hour, from: roundedDateToNearestMinutes(date, minutes: nearestMinutes)))
  }

  public func accentedMinute(for date: Date) -> Int {
      let minute = Double(component(.minute, from: roundedDateToNearestMinutes(date, minutes: nearestMinutes)))
    let value = interval.rawValue * Int(round(minute / Double(interval.rawValue)))
    return value < 60 ? value : 0
  }
  
  private func component(_ component: Calendar.Component, from date: Date) -> Int {
    calendar.component(component, from: date)
  }
    

    public func roundedDateToNearestMinutes(_ date: Date, minutes: NSInteger) -> Date {
      let targetSeconds : Double = Double(minutes) * 60.0
      let seconds = round(date.timeIntervalSinceReferenceDate / targetSeconds) * targetSeconds
      return Date(timeIntervalSinceReferenceDate: seconds)
  }
    
}
