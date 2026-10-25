import Foundation

public struct TimeSegment: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date?
    public var isRunning: Bool { end == nil }

    public init(id: String, title: String, start: Date, end: Date?) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
    }

    public func resolvedEnd(now: Date) -> Date {
        end ?? now
    }

    public func duration(now: Date) -> TimeInterval {
        resolvedEnd(now: now).timeIntervalSince(start)
    }
}

public enum Scope: String, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .day: return "日"
        case .week: return "周"
        case .month: return "月"
        }
    }
}

public struct CalendarRange: Equatable, Sendable {
    public var scope: Scope
    public var anchor: Date

    public static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.firstWeekday = 2
        calendar.timeZone = .current
        return calendar
    }()

    public init(scope: Scope, anchor: Date) {
        self.scope = scope
        self.anchor = anchor
    }

    public var interval: DateInterval {
        let calendar = Self.calendar
        switch scope {
        case .day:
            let start = calendar.startOfDay(for: anchor)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .week:
            let start = calendar.dateInterval(of: .weekOfYear, for: anchor)?.start ?? calendar.startOfDay(for: anchor)
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .month:
            let start = calendar.dateInterval(of: .month, for: anchor)?.start ?? calendar.startOfDay(for: anchor)
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        }
    }

    public func shifting(_ step: Int) -> CalendarRange {
        let calendar = Self.calendar
        let component: Calendar.Component
        switch scope {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        }
        let next = calendar.date(byAdding: component, value: step, to: anchor) ?? anchor
        return CalendarRange(scope: scope, anchor: next)
    }

    public var title: String {
        let calendar = Self.calendar
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = calendar.timeZone
        switch scope {
        case .day:
            formatter.dateFormat = "M月d日 EEE"
            return formatter.string(from: anchor)
        case .week:
            formatter.dateFormat = "M月d日"
            let start = interval.start
            let sunday = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            return "\(formatter.string(from: start)) – \(formatter.string(from: sunday))"
        case .month:
            formatter.dateFormat = "yyyy年M月"
            return formatter.string(from: anchor)
        }
    }

    public func contains(_ date: Date) -> Bool {
        interval.contains(date)
    }
}

public struct LanePlacement: Equatable, Sendable {
    public var lane: Int
    public var laneCount: Int

    public init(lane: Int, laneCount: Int) {
        self.lane = lane
        self.laneCount = laneCount
    }
}

public func assignLanes(_ items: [(id: String, start: Date, end: Date)]) -> [String: LanePlacement] {
    let sorted = items.sorted { lhs, rhs in
        if lhs.start == rhs.start { return lhs.id < rhs.id }
        return lhs.start < rhs.start
    }
    var laneEnds: [Date] = []
    var laneOf: [String: Int] = [:]
    for item in sorted {
        if let index = laneEnds.firstIndex(where: { $0 <= item.start }) {
            laneEnds[index] = item.end
            laneOf[item.id] = index
        } else {
            laneOf[item.id] = laneEnds.count
            laneEnds.append(item.end)
        }
    }
    var result: [String: LanePlacement] = [:]
    for item in sorted {
        let lane = laneOf[item.id] ?? 0
        let overlapping = sorted.filter { other in
            other.start < item.end && item.start < other.end
        }
        let count = (overlapping.compactMap { laneOf[$0.id] }.max() ?? lane) + 1
        result[item.id] = LanePlacement(lane: lane, laneCount: max(count, 1))
    }
    return result
}

public func segments(_ segments: [TimeSegment], overlapping interval: DateInterval, now: Date) -> [TimeSegment] {
    segments.filter { segment in
        segment.start < interval.end && segment.resolvedEnd(now: now) > interval.start
    }
}

public extension Calendar {
    func startOfDay(_ date: Date) -> Date {
        self.startOfDay(for: date)
    }
}
