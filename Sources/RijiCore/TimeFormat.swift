import Foundation

public func durationText(from start: Date, to end: Date) -> String {
    let seconds = max(0, Int(end.timeIntervalSince(start).rounded()))
    if seconds < 60 {
        return "\(seconds)秒"
    }
    let minutes = Int((Double(seconds) / 60.0).rounded())
    if minutes < 60 {
        return "\(minutes)分钟"
    }
    let hours = minutes / 60
    let remain = minutes % 60
    if remain == 0 {
        return "\(hours)小时"
    }
    return "\(hours)小时\(remain)分"
}

public func clockText(from start: Date, to end: Date) -> String {
    let seconds = max(0, Int(end.timeIntervalSince(start).rounded()))
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let secs = seconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%02d:%02d", minutes, secs)
}

public func cleanTitle(_ raw: String) -> String {
    let pattern = #" · (?:\d+小时(?:\d+分)?|\d+分钟|\d+秒)$"#
    guard let range = raw.range(of: pattern, options: .regularExpression) else {
        return raw
    }
    return String(raw[..<range.lowerBound])
}

public func dayStamp(_ date: Date, calendar: Calendar = CalendarRange.calendar) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

public func logStamp(_ date: Date, calendar: Calendar = CalendarRange.calendar) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter.string(from: date)
}

public func parseLogStamp(_ text: String, calendar: Calendar = CalendarRange.calendar) -> Date? {
    var value = text.trimmingCharacters(in: .whitespaces)
    if value.count == 16 {
        value += ":00"
    }
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter.date(from: value)
}
