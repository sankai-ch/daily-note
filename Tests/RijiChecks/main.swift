import Foundation
import RijiCore

var failures = 0

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        failures += 1
        fputs("FAIL \(message)\n", stderr)
    }
}

let start = Date(timeIntervalSince1970: 0)
expect(durationText(from: start, to: start.addingTimeInterval(37 * 60)) == "37分钟", "37 minutes")
expect(durationText(from: start, to: start.addingTimeInterval(97 * 60)) == "1小时37分", "1h37")
expect(durationText(from: start, to: start.addingTimeInterval(3600)) == "1小时", "1 hour")
expect(durationText(from: start, to: start.addingTimeInterval(45)) == "45秒", "45 seconds")
expect(cleanTitle("写口播稿 · 1小时37分") == "写口播稿", "clean duration")
expect(cleanTitle("开会 · 讨论") == "开会 · 讨论", "keep non-duration suffix")

let original = """
---
date: 2026-10-24
---

# Day planner

- [ ] 09:30 - 11:30 写稿 @内容

# 小结

-

"""
let loggedStart = parseLogStamp("2026-10-24 22:10:00")!
let loggedEnd = parseLogStamp("2026-10-24 22:47:00")!
let block = DailyNote.renderBlock(title: "写口播稿", start: loggedStart, end: loggedEnd)
let updated = DailyNote.insertBlock(block, into: original)
expect(updated.contains("- [ ] 09:30 - 11:30 写稿 @内容"), "keeps plan")
expect(updated.contains("- [x] 写口播稿 · 37分钟"), "writes duration")
expect(updated.contains("start: 2026-10-24 22:10:00"), "writes start")
expect(updated.contains("end: 2026-10-24 22:47:00"), "writes end")
expect(
    updated.range(of: "- [x] 写口播稿")!.lowerBound < updated.range(of: "# 小结")!.lowerBound,
    "inserts before summary"
)
let parsed = DailyNote.parse(text: updated)
expect(parsed.count == 1 && parsed[0].title == "写口播稿" && parsed[0].end == loggedEnd, "parses written block")

let created = DailyNote.insertBlock(
    DailyNote.renderBlock(
        title: "复盘",
        start: parseLogStamp("2026-10-24 21:00:00")!,
        end: parseLogStamp("2026-10-24 21:18:00")!
    ),
    into: "随便写的\n"
)
expect(created.contains("# Day planner"), "creates heading")
expect(DailyNote.parse(text: created).map(\.title) == ["复盘"], "parses created note")

let base = Date(timeIntervalSince1970: 0)
let lanes = assignLanes([
    ("a", base, base.addingTimeInterval(3600)),
    ("b", base.addingTimeInterval(1800), base.addingTimeInterval(5400)),
    ("c", base.addingTimeInterval(8000), base.addingTimeInterval(9000)),
])
expect(lanes["a"]?.lane != lanes["b"]?.lane, "overlap uses two lanes")
expect(lanes["a"]?.laneCount == 2, "overlap lane count")
expect(lanes["c"]?.laneCount == 1, "later block is full width")

let saturday = parseLogStamp("2026-10-24 12:00:00")!
let week = CalendarRange(scope: .week, anchor: saturday)
expect(dayStamp(week.interval.start) == "2026-10-19", "week starts Monday")
expect(dayStamp(week.interval.end) == "2026-10-26", "week ends next Monday")

if failures > 0 {
    fputs("\(failures) failed\n", stderr)
    exit(1)
}
print("ok")
