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
  
  public init(_ calendar: Calendar = Calendar.autoupdatingCurrent) {
    self.calendar = calendar
  }

  public func nearestDate(to date: Date) -> Date {
      let unit: Double = Double(interval.rawValue / 2)
    var accentedHour = Int(self.accentedHour(for: date))
    let minute = Double(component(.minute, from: date))
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
    
    let day = calendar.date(byAdding: DateComponents(day: dayOffset), to: date)!
    return calendar.date(bySettingHour: accentedHour,
                         minute: accentedMinute(for: date),
                         second: 0,
                         of: day)!
  }

  public func accentedHour(for date: Date) -> Int {
    Int(component(.hour, from: date))
  }

  public func accentedMinute(for date: Date) -> Int {
    let minute = Double(component(.minute, from: date))
      let value = interval.rawValue * Int(round(minute / Double(interval.rawValue)))
    return value < 60 ? value : 0
  }
  
  private func component(_ component: Calendar.Component, from date: Date) -> Int {
    calendar.component(component, from: date)
  }
}
