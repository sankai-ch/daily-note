import RijiCore
import SwiftUI

struct WorkbenchView: View {
    @ObservedObject var model: AppModel

    private var theme: Theme { Theme.resolve(model.colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle()
                .fill(theme.line)
                .frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if model.showsTimeline {
                        TimelinePage(model: model)
                    } else {
                        DashboardPage(model: model)
                    }
                }
                .padding(18)
            }
            Rectangle()
                .fill(theme.line)
                .frame(height: 1)
            Text(model.quote)
                .font(.system(size: 15))
                .foregroundStyle(theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
        }
        .background(theme.paper)
        .environment(\.theme, theme)
        .preferredColorScheme(model.colorScheme)
        .onAppear {
            model.reload()
            model.refreshScheme()
        }
    }

    private var toolbar: some View {
        HStack {
            Picker("页面", selection: $model.showsTimeline) {
                Text("总览").tag(false)
                Text("时间轴").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            Spacer()

            Button { model.shift(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.plain)
                .foregroundStyle(theme.ink)
            Text(model.range.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.ink)
                .frame(minWidth: 180)
            Button { model.shift(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.plain)
                .foregroundStyle(theme.ink)

            Spacer()

            Picker("范围", selection: $model.scope) {
                ForEach(Scope.allCases) { scope in
                    Text(scope.label).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)

            Picker("主题", selection: $model.themeChoice) {
                ForEach(ThemeChoice.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 168)
            .padding(.leading, 12)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

struct DashboardPage: View {
    @ObservedObject var model: AppModel
    @Environment(\.theme) private var theme

    private var period: [TimeSegment] {
        model.segments.filter { model.range.interval.contains($0.start) }
    }

    private var total: TimeInterval {
        period.reduce(0) { $0 + $1.duration(now: model.now) }
    }

    private var stoppedTotal: TimeInterval {
        period.filter { !$0.isRunning }.reduce(0) { $0 + $1.duration(now: model.now) }
    }

    private var longest: TimeSegment? {
        period.max { $0.duration(now: model.now) < $1.duration(now: model.now) }
    }

    private var ranking: [(title: String, duration: TimeInterval, running: Bool)] {
        let grouped = Dictionary(grouping: period, by: \.title)
        return grouped.map { title, items in
            (
                title,
                items.reduce(0) { $0 + $1.duration(now: model.now) },
                items.contains { $0.isRunning }
            )
        }
        .sorted { $0.duration > $1.duration }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Card {
                    label("进行中")
                    if model.running.isEmpty {
                        Text("没有正在做的事")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.muted)
                    } else {
                        ForEach(model.running) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(theme.ink)
                                    Text("\(clock(entry.start)) 开始 · 已 \(durationText(from: entry.start, to: model.now))")
                                        .font(.system(size: 12))
                                        .foregroundStyle(theme.muted)
                                }
                                Spacer()
                                Button(action: { model.stop(entry) }) {
                                    Text("停止")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(theme.ink)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(theme.pill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                Card {
                    label("这段时间合计")
                    Text(durationText(seconds: stoppedTotal))
                        .font(.system(size: 40, weight: .medium, design: .serif))
                        .foregroundStyle(theme.ink)
                    Text(model.running.isEmpty ? "已停下的记录" : "已停下的记录 · 另有 \(model.running.count) 件还在走")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.muted)
                    if let longest {
                        Text("最长的一段")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.faint)
                            .padding(.top, 12)
                        Text("\(longest.title) · \(durationText(from: longest.start, to: longest.resolvedEnd(now: model.now)))")
                            .font(.system(size: 14))
                    }
                }
            }

            Card {
                label("事项排行")
                if ranking.isEmpty {
                    Text("这段时间还没有记录")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.muted)
                } else {
                    let maxDuration = ranking.map(\.duration).max() ?? 1
                    ForEach(ranking, id: \.title) { item in
                        HStack(spacing: 10) {
                            Text(item.title)
                                .font(.system(size: 13))
                                .foregroundStyle(theme.ink)
                                .frame(width: 92, alignment: .leading)
                                .lineLimit(1)
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(theme.line)
                                    Capsule()
                                        .fill(theme.task(item.title))
                                        .frame(width: max(6, proxy.size.width * item.duration / maxDuration))
                                }
                            }
                            .frame(height: 7)
                            Text(item.running ? "进行中" : durationText(seconds: item.duration))
                                .font(.system(size: 12))
                                .foregroundStyle(theme.muted)
                                .frame(width: 78, alignment: .trailing)
                        }
                    }
                }
            }

            if model.scope != .day {
                Card {
                    label("每天用量")
                    DayBars(model: model, segments: period)
                        .frame(height: 140)
                }
            }
        }
    }

    private func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct DayBars: View {
    @ObservedObject var model: AppModel
    @Environment(\.theme) private var theme
    var segments: [TimeSegment]

    var body: some View {
        let days = daysInRange()
        let totals = days.map { day -> (Date, TimeInterval) in
            let start = CalendarRange.calendar.startOfDay(for: day)
            let end = CalendarRange.calendar.date(byAdding: .day, value: 1, to: start) ?? start
            let total = segments.filter { $0.start >= start && $0.start < end }
                .reduce(0) { $0 + $1.duration(now: model.now) }
            return (start, total)
        }
        let maxTotal = totals.map(\.1).max() ?? 1
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(totals, id: \.0) { day, total in
                Button {
                    model.showDay(day)
                } label: {
                    VStack(spacing: 6) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(CalendarRange.calendar.isDateInToday(day) ? theme.moss : theme.sea.opacity(0.75))
                            .frame(height: max(4, 96 * total / max(maxTotal, 1)))
                        Text(dayLabel(day))
                            .font(.system(size: 10, weight: CalendarRange.calendar.isDateInToday(day) ? .semibold : .regular))
                            .foregroundStyle(CalendarRange.calendar.isDateInToday(day) ? theme.moss : theme.muted)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func daysInRange() -> [Date] {
        let calendar = CalendarRange.calendar
        var days: [Date] = []
        var cursor = model.range.interval.start
        while cursor < model.range.interval.end {
            days.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? model.range.interval.end
        }
        return days
    }

    private func dayLabel(_ date: Date) -> String {
        if model.scope == .week {
            let symbols = ["日", "一", "二", "三", "四", "五", "六"]
            let weekday = CalendarRange.calendar.component(.weekday, from: date)
            return symbols[weekday - 1]
        }
        return String(CalendarRange.calendar.component(.day, from: date))
    }
}

private struct Card<Content: View>: View {
    @Environment(\.theme) private var theme
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(theme.sheet, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(theme.line, lineWidth: 1)
        )
    }
}

private struct SectionLabel: View {
    @Environment(\.theme) private var theme
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .tracking(1.4)
            .foregroundStyle(theme.faint)
    }
}

private func label(_ text: String) -> some View {
    SectionLabel(text: text)
}

func durationText(seconds: TimeInterval) -> String {
    let start = Date(timeIntervalSince1970: 0)
    return durationText(from: start, to: start.addingTimeInterval(max(0, seconds)))
}
