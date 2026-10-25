import Foundation

public enum DailyNote {
    public static func skeleton(day: String) -> String {
        """
        ---
        date: \(day)
        ---

        # Day planner

        # 小结

        -

        """
    }

    public static func renderBlock(title: String, start: Date, end: Date) -> String {
        let name = cleanTitle(title)
        return """
        - [x] \(name) · \(durationText(from: start, to: end))
          ```yaml
          planner:
            log:
              - start: \(logStamp(start))
                end: \(logStamp(end))
          ```
        """
    }

    public static func insertBlock(_ block: String, into original: String) -> String {
        var text = original.replacingOccurrences(of: "\r\n", with: "\n")
        if !text.hasSuffix("\n") {
            text += "\n"
        }
        var lines = text.components(separatedBy: "\n")
        guard let plannerIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "# Day planner" }) else {
            if lines.last == "" {
                lines.removeLast()
            }
            if lines.last?.isEmpty == false {
                lines.append("")
            }
            lines.append("# Day planner")
            lines.append("")
            lines.append(contentsOf: block.components(separatedBy: "\n"))
            lines.append("")
            return lines.joined(separator: "\n")
        }

        let nextHeading = lines.indices.first { index in
            index > plannerIndex && isHeading1(lines[index])
        }
        var insertAt = nextHeading ?? lines.count
        if nextHeading == nil, lines.last == "" {
            insertAt = lines.count - 1
        }

        var piece = block.components(separatedBy: "\n")
        if insertAt > 0, lines[insertAt - 1] != "" {
            piece.insert("", at: 0)
        }
        if insertAt < lines.count, lines[insertAt] != "" {
            piece.append("")
        }
        lines.insert(contentsOf: piece, at: insertAt)
        return lines.joined(separator: "\n")
    }

    public static func parse(text: String, fileID: String = "note") -> [TimeSegment] {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var inPlanner = false
        var segments: [TimeSegment] = []
        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if isHeading1(lines[index]) {
                inPlanner = trimmed == "# Day planner"
                continue
            }
            guard inPlanner, let rawTitle = taskTitle(lines[index]) else { continue }
            let logs = logEntries(in: lines, after: index)
            for (offset, log) in logs.enumerated() {
                guard let end = log.end else { continue }
                let title = cleanTitle(rawTitle)
                segments.append(TimeSegment(
                    id: "\(fileID)#\(index)#\(offset)#\(logStamp(log.start))",
                    title: title,
                    start: log.start,
                    end: end
                ))
            }
        }
        return segments
    }

    public static func append(title: String, start: Date, end: Date, directory: URL) throws {
        let day = dayStamp(start)
        let url = directory.appendingPathComponent("\(day).md")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try skeleton(day: day).write(to: url, atomically: true, encoding: .utf8)
        }
        let block = renderBlock(title: title, start: start, end: end)
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: &coordinationError) { coordinated in
            do {
                let existing = try String(contentsOf: coordinated, encoding: .utf8)
                let updated = insertBlock(block, into: existing)
                try updated.write(to: coordinated, atomically: true, encoding: .utf8)
            } catch {
                writeError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let writeError { throw writeError }
    }

    public static func loadAll(in directory: URL) -> [TimeSegment] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        return files.flatMap { url in
            let name = url.lastPathComponent
            guard name.range(of: #"^\d{4}-\d{2}-\d{2}\.md$"#, options: .regularExpression) != nil else {
                return [TimeSegment]()
            }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                return []
            }
            return parse(text: text, fileID: url.lastPathComponent)
        }
    }

    private static func isHeading1(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("# ") && !trimmed.hasPrefix("##")
    }

    private static func taskTitle(_ line: String) -> String? {
        let pattern = #"^\s*- \[[ xX]\]\s+(.+?)\s*$"#
        guard let match = line.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        let matched = String(line[match])
        guard let content = matched.range(of: #"^\s*- \[[ xX]\]\s+"#, options: .regularExpression) else {
            return nil
        }
        return String(matched[content.upperBound...]).trimmingCharacters(in: .whitespaces)
    }

    private static func logEntries(in lines: [String], after index: Int) -> [(start: Date, end: Date?)] {
        var cursor = index + 1
        while cursor < lines.count, lines[cursor].trimmingCharacters(in: .whitespaces).isEmpty {
            cursor += 1
        }
        guard cursor < lines.count, lines[cursor].contains("```") else { return [] }
        cursor += 1
        var body: [String] = []
        while cursor < lines.count, !lines[cursor].contains("```") {
            body.append(lines[cursor])
            cursor += 1
        }
        return parseLogBody(body.joined(separator: "\n"))
    }

    private static func parseLogBody(_ body: String) -> [(start: Date, end: Date?)] {
        let pattern = #"(start|end):\s*(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}(?::\d{2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(body.startIndex..., in: body)
        let matches = regex.matches(in: body, range: range)
        var result: [(start: Date, end: Date?)] = []
        var openStart: Date?
        for match in matches {
            guard let kindRange = Range(match.range(at: 1), in: body),
                  let stampRange = Range(match.range(at: 2), in: body),
                  let date = parseLogStamp(String(body[stampRange])) else {
                continue
            }
            let kind = String(body[kindRange])
            if kind == "start" {
                if let openStart {
                    result.append((openStart, nil))
                }
                openStart = date
            } else if kind == "end", let start = openStart {
                result.append((start, date))
                openStart = nil
            }
        }
        if let openStart {
            result.append((openStart, nil))
        }
        return result
    }
}

public struct RunningEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var start: Date

    public init(id: UUID, title: String, start: Date) {
        self.id = id
        self.title = title
        self.start = start
    }
}

public enum RunningStore {
    public static func fileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("日计/running.json")
    }

    public static func load(from url: URL = fileURL()) -> [RunningEntry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([RunningEntry].self, from: data)) ?? []
    }

    public static func save(_ entries: [RunningEntry], to url: URL = fileURL()) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(entries)
        try data.write(to: url, options: .atomic)
    }
}
