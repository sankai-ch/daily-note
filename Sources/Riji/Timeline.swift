import RijiCore
import SwiftUI

struct TimelinePage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        switch model.scope {
        case .day:
            DayBoard(model: model)
        case .week:
            WeekBoard(model: model)
        case .month:
            MonthCalendar(model: model)
        }
    }
}

struct DayBoard: View {
    @ObservedObject var model: AppModel
    @Environment(\.theme) private var theme

    var body: some View {
        let load = SpanLoad.day(model.anchor, segments: model.segments, now: model.now)
        VStack(alignment: .leading, spacing: 16) {
            SpanRibbon(items: load.items, now: load.isToday ? model.now : nil, laneHeight: 52, showsTitles: true)
            if load.items.isEmpty {
                Text("这一天还没有记录")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(load.items.enumerated()), id: \.element.id) { index, item in
                        sessionRow(item)
                        if index < load.items.count - 1 {
                            Rectangle()
                                .fill(theme.line)
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.sheet, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(theme.line, lineWidth: 1)
        )
    }

    private func sessionRow(_ item: SpanItem) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(item.running ? theme.task(item.title) : Theme.blockFill(item.title))
                .frame(width: 4, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text(item.running
                     ? "\(SpanMath.clock(item.start)) 开始 · 进行中"
                     : "\(SpanMath.clock(item.start)) – \(SpanMath.clock(item.end))")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.muted)
            }
            Spacer(minLength: 8)
            Text(durationText(from: item.start, to: item.running ? model.now : item.end))
                .font(.system(size: 13))
                .foregroundStyle(theme.muted)
        }
        .padding(.vertical, 8)
    }
}

struct WeekBoard: View {
    @ObservedObject var model: AppModel
    @Environment(\.theme) private var theme

    var body: some View {
        let calendar = CalendarRange.calendar
        let start = model.range.interval.start
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        VStack(alignment: .leading, spacing: 6) {
            ForEach(days, id: \.timeIntervalSince1970) { day in
                weekRow(day)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.sheet, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(theme.line, lineWidth: 1)
        )
    }

    private func weekRow(_ day: Date) -> some View {
        let load = SpanLoad.day(day, segments: model.segments, now: model.now)
        let total = load.items.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
        return Button {
            model.showDay(day)
        } label: {
            HStack(spacing: 8) {
                Text(SpanMath.weekdayLabel(day))
                    .font(.system(size: 12, weight: load.isToday ? .semibold : .regular))
                    .foregroundStyle(load.isToday ? theme.moss : theme.muted)
                    .frame(width: 68, alignment: .leading)
                SpanRibbon(
                    items: load.items,
                    now: load.isToday ? model.now : nil,
                    laneHeight: 24,
                    showsTitles: false
                )
                Text(total > 0 ? durationText(seconds: total) : "—")
                    .font(.system(size: 11))
                    .foregroundStyle(total > 0 ? theme.muted : theme.faint)
                    .lineLimit(1)
                    .frame(width: 68, alignment: .trailing)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 4)
            .background(
                load.isToday ? theme.today : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SpanRibbon: View {
    var items: [SpanItem]
    var now: Date?
    var laneHeight: CGFloat
    var showsTitles: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        let rowLanes = ElasticTrack.rowLanes(items)
        let height = CGFloat(rowLanes) * laneHeight
        GeometryReader { geo in
            let pieces = ElasticTrack.pieces(items: items, now: now, width: geo.size.width, showsTitles: showsTitles)
            ZStack(alignment: .topLeading) {
                if items.isEmpty {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.cell)
                }
                ForEach(pieces) { piece in
                    if let gap = piece.gap {
                        gapMark(gap, width: piece.width, marksNow: piece.marksNow)
                            .offset(x: piece.x, y: (height - 22) / 2)
                    } else if let slot = piece.slot {
                        slotView(slot, width: piece.width, rowHeight: height)
                            .offset(x: piece.x)
                    }
                }
            }
        }
        .frame(height: height)
    }

    private func slotView(_ slot: ElasticTrack.Slot, width: CGFloat, rowHeight: CGFloat) -> some View {
        let lanes = assignLanes(slot.items.map { ($0.id, $0.start, $0.end) })
        let laneCount = max(1, (lanes.values.map(\.lane).max() ?? 0) + 1)
        let slotHeight = CGFloat(laneCount) * laneHeight
        return ZStack(alignment: .topLeading) {
            ForEach(slot.items) { item in
                let lane = lanes[item.id]?.lane ?? 0
                chip(item, wide: showsTitles && width > 96)
                    .frame(width: max(4, width), height: laneHeight - 8)
                    .offset(y: CGFloat(lane) * laneHeight + 4)
            }
        }
        .frame(width: width, height: slotHeight, alignment: .topLeading)
        .offset(y: max(0, (rowHeight - slotHeight) / 2))
    }

    private func gapMark(_ duration: TimeInterval, width: CGFloat, marksNow: Bool) -> some View {
        let label = width >= (showsTitles ? 68 : 44) ? "空 \(durationText(seconds: duration))" : "···"
        return HStack(spacing: 4) {
            if marksNow {
                Circle()
                    .fill(theme.now)
                    .frame(width: 6, height: 6)
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(theme.faint)
                .lineLimit(1)
        }
        .frame(width: width, height: 22)
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(theme.line, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
        )
        .help("空了 \(durationText(seconds: duration))")
    }

    private func chip(_ item: SpanItem, wide: Bool) -> some View {
        let accent = theme.task(item.title)
        let fill = Theme.blockFill(item.title)
        let title = item.running ? "\(item.title) · 进行中" : item.title
        return VStack(alignment: .leading, spacing: 1) {
            Text(wide ? title : "")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            if wide {
                Text(item.running
                     ? "\(SpanMath.clock(item.start)) 开始"
                     : "\(SpanMath.clock(item.start))–\(SpanMath.clock(item.end))")
                    .font(.system(size: 10))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(item.running ? accent : Color.white)
        .padding(.horizontal, wide ? 8 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(item.running ? accent.opacity(theme.ghostWash) : fill)
            if item.running {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(accent, style: StrokeStyle(lineWidth: 1.4, dash: [4, 3]))
            }
        }
        .help(item.running
              ? "\(item.title) · \(SpanMath.clock(item.start)) 开始"
              : "\(item.title) · \(SpanMath.clock(item.start))–\(SpanMath.clock(item.end)) · \(durationText(from: item.start, to: item.end))")
    }
}

enum ElasticTrack {
    struct Slot {
        var items: [SpanItem]
        var start: Date
        var end: Date
        var id: String { items.map(\.id).joined(separator: "|") }
    }

    struct Piece: Identifiable {
        var id: String
        var x: CGFloat
        var width: CGFloat
        var slot: Slot?
        var gap: TimeInterval?
        var marksNow: Bool
    }

    static let compressAfter: TimeInterval = 45 * 60

    static func rowLanes(_ items: [SpanItem]) -> Int {
        let slots = cluster(items)
        let counts = slots.map { slot -> Int in
            let lanes = assignLanes(slot.items.map { ($0.id, $0.start, $0.end) })
            return max(1, (lanes.values.map(\.lane).max() ?? 0) + 1)
        }
        return max(1, counts.max() ?? 1)
    }

    static func pieces(items: [SpanItem], now: Date?, width: CGFloat, showsTitles: Bool) -> [Piece] {
        let slots = cluster(items)
        guard !slots.isEmpty, width > 1 else { return [] }
        let gaps = gapBefore(slots)
        let trailing = trailingGap(slots, now: now)
        let metrics = metrics(count: slots.count, showsTitles: showsTitles)
        var gapWidths = gaps.map { $0 >= compressAfter ? metrics.gapPreferred : CGFloat(0) }
        var trailingWidth: CGFloat = trailing >= compressAfter ? metrics.gapPreferred : 0
        let gutterIndexes = gaps.enumerated().filter { $0.offset > 0 && $0.element < compressAfter }.map(\.offset)
        var gutter = metrics.gutter
        var slotWidths = Array(repeating: metrics.taskMin, count: slots.count)

        func used() -> CGFloat {
            slotWidths.reduce(0, +) + gapWidths.reduce(0, +) + trailingWidth + gutter * CGFloat(gutterIndexes.count)
        }

        while used() > width, gapWidths.contains(where: { $0 > metrics.gapMin }) || trailingWidth > metrics.gapMin {
            gapWidths = gapWidths.map { $0 > 0 ? max(metrics.gapMin, $0 - 4) : 0 }
            if trailingWidth > 0 {
                trailingWidth = max(metrics.gapMin, trailingWidth - 4)
            }
        }
        while used() > width, gutter > 4 {
            gutter -= 1
        }
        if used() > width {
            let fixed = gapWidths.reduce(0, +) + trailingWidth + gutter * CGFloat(gutterIndexes.count)
            let each = max(8, (width - fixed) / CGFloat(max(slots.count, 1)))
            slotWidths = Array(repeating: each, count: slots.count)
        } else {
            let extra = width - used()
            let weights = slots.map { max($0.end.timeIntervalSince($0.start), 8 * 60) }
            let sum = weights.reduce(0, +)
            if sum > 0 {
                for index in slots.indices {
                    slotWidths[index] += extra * CGFloat(weights[index] / sum)
                }
            }
        }
        let fitted = used()
        if fitted > width, fitted > 0 {
            let scale = width / fitted
            slotWidths = slotWidths.map { $0 * scale }
            gapWidths = gapWidths.map { $0 * scale }
            trailingWidth *= scale
            gutter *= scale
        }
        let drift = width - used()
        if let last = slotWidths.indices.last {
            slotWidths[last] = max(8, slotWidths[last] + drift)
        }

        var pieces: [Piece] = []
        var cursor: CGFloat = 0
        for index in slots.indices {
            if gapWidths[index] > 0 {
                let start = index == 0 ? slots[index].start : slots[index - 1].end
                pieces.append(Piece(
                    id: "gap-\(index)",
                    x: cursor,
                    width: gapWidths[index],
                    slot: nil,
                    gap: gaps[index],
                    marksNow: contains(now, from: start, to: slots[index].start)
                ))
                cursor += gapWidths[index]
            } else if gutterIndexes.contains(index) {
                cursor += gutter
            }
            pieces.append(Piece(
                id: slots[index].id,
                x: cursor,
                width: slotWidths[index],
                slot: slots[index],
                gap: nil,
                marksNow: false
            ))
            cursor += slotWidths[index]
        }
        if trailingWidth > 0, let last = slots.last {
            pieces.append(Piece(
                id: "gap-end",
                x: cursor,
                width: trailingWidth,
                slot: nil,
                gap: trailing,
                marksNow: contains(now, from: last.end, to: now)
            ))
        }
        return pieces
    }

    private static func cluster(_ items: [SpanItem]) -> [Slot] {
        var slots: [Slot] = []
        for item in items.sorted(by: { $0.start < $1.start }) {
            if let index = slots.indices.last, item.start < slots[index].end {
                slots[index].items.append(item)
                slots[index].end = max(slots[index].end, item.end)
            } else {
                slots.append(Slot(items: [item], start: item.start, end: item.end))
            }
        }
        return slots
    }

    private static func gapBefore(_ slots: [Slot]) -> [TimeInterval] {
        slots.enumerated().map { index, slot in
            guard index > 0 else { return 0 }
            return slot.start.timeIntervalSince(slots[index - 1].end)
        }
    }

    private static func trailingGap(_ slots: [Slot], now: Date?) -> TimeInterval {
        guard let now, let last = slots.last else { return 0 }
        return max(0, now.timeIntervalSince(last.end))
    }

    private static func contains(_ now: Date?, from start: Date, to end: Date?) -> Bool {
        guard let now, let end else { return false }
        return now >= start && now <= end
    }

    private static func metrics(count: Int, showsTitles: Bool) -> (taskMin: CGFloat, gutter: CGFloat, gapPreferred: CGFloat, gapMin: CGFloat) {
        if showsTitles {
            let gutter: CGFloat = count <= 3 ? 16 : (count <= 7 ? 12 : 8)
            return (84, gutter, 76, 28)
        }
        let gutter: CGFloat = count <= 3 ? 8 : 5
        return (18, gutter, 36, 14)
    }
}

struct SpanItem: Identifiable {
    var id: String
    var title: String
    var start: Date
    var end: Date
    var running: Bool
}

struct SpanLoad {
    var dayStart: Date
    var dayEnd: Date
    var isToday: Bool
    var items: [SpanItem]

    static func day(_ date: Date, segments source: [TimeSegment], now: Date) -> SpanLoad {
        let calendar = CalendarRange.calendar
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let interval = DateInterval(start: start, end: end)
        let visible = segments(source, overlapping: interval, now: now)
        let items = visible.compactMap { segment -> SpanItem? in
            let clippedStart = max(segment.start, start)
            let clippedEnd = min(segment.resolvedEnd(now: now), end)
            guard clippedEnd > clippedStart else { return nil }
            return SpanItem(
                id: segment.id,
                title: segment.title,
                start: clippedStart,
                end: clippedEnd,
                running: segment.isRunning && abs(clippedEnd.timeIntervalSince(now)) < 2
            )
        }
        .sorted { $0.start < $1.start }
        return SpanLoad(
            dayStart: start,
            dayEnd: end,
            isToday: calendar.isDate(start, inSameDayAs: now),
            items: items
        )
    }
}

enum SpanMath {
    static func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func weekdayLabel(_ date: Date) -> String {
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]
        let calendar = CalendarRange.calendar
        let weekday = calendar.component(.weekday, from: date)
        let day = calendar.component(.day, from: date)
        return "周\(symbols[weekday - 1]) \(day)"
    }
}

struct MonthCalendar: View {
    @ObservedObject var model: AppModel
    @Environment(\.theme) private var theme

    var body: some View {
        let calendar = CalendarRange.calendar
        let interval = model.range.interval
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday + 5) % 7
        let dayCount = calendar.range(of: .day, in: .month, for: interval.start)?.count ?? 30
        let cells = leading + dayCount

        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { name in
                    Text(name)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.faint)
                        .frame(maxWidth: .infinity)
                }
                ForEach(0..<cells, id: \.self) { index in
                    if index < leading {
                        Color.clear.frame(height: 72)
                    } else {
                        let day = index - leading + 1
                        let date = calendar.date(byAdding: .day, value: day - 1, to: interval.start) ?? interval.start
                        dayCell(date)
                    }
                }
            }
        }
        .padding(12)
        .background(theme.sheet, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(theme.line, lineWidth: 1)
        )
    }

    private func dayCell(_ date: Date) -> some View {
        let calendar = CalendarRange.calendar
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let total = model.segments.filter { $0.start >= start && $0.start < end }
            .reduce(0) { $0 + $1.duration(now: model.now) }
        let today = calendar.isDateInToday(date)
        return Button {
            model.showDay(date)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 12, weight: today ? .semibold : .regular))
                    .foregroundStyle(today ? theme.moss : theme.faint)
                if total > 0 {
                    Text(durationText(seconds: total))
                        .font(.system(size: 11))
                        .foregroundStyle(theme.moss)
                        .lineLimit(1)
                    Capsule()
                        .fill(theme.moss)
                        .frame(height: 4)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
            .background(
                today ? theme.today : theme.cell,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                if today {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(theme.moss, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
