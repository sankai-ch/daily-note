import AppKit
import Foundation
import RijiCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var now = Date()
    @Published var draft = ""
    @Published var running: [RunningEntry] = []
    @Published var completed: [TimeSegment] = []
    @Published var scope: Scope = .day
    @Published var anchor = Date()
    @Published var showsTimeline = false
    @Published var errorMessage: String?
    @Published var quote = QuoteLine.next()
    @Published var themeChoice: ThemeChoice = SystemAppearance.storedChoice {
        didSet {
            guard themeChoice != oldValue else { return }
            UserDefaults.standard.set(themeChoice.rawValue, forKey: SystemAppearance.choiceKey)
            refreshScheme()
        }
    }
    @Published var colorScheme: ColorScheme = SystemAppearance.resolved(SystemAppearance.storedChoice)

    @Published var notesDirectory = NotesLocation.resolve()

    private var timer: Timer?
    private var ticks = 0
    private var appearanceObserver: NSObjectProtocol?

    var range: CalendarRange {
        CalendarRange(scope: scope, anchor: anchor)
    }

    var segments: [TimeSegment] {
        completed + running.map { entry in
            TimeSegment(id: entry.id.uuidString, title: entry.title, start: entry.start, end: nil)
        }
    }

    var menuTitle: String {
        if running.isEmpty { return "" }
        if running.count == 1, let entry = running.first {
            let name = entry.title.count > 6 ? String(entry.title.prefix(6)) + "…" : entry.title
            return "\(name) \(clockText(from: entry.start, to: now))"
        }
        return "\(running.count) 项"
    }

    func bootstrap() {
        reload()
        watchAppearance()
        refreshScheme()
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func tick() {
        now = Date()
        refreshScheme()
        ticks += 1
        if ticks % 30 == 0 {
            completed = DailyNote.loadAll(in: notesDirectory)
        }
    }

    func refreshScheme() {
        let next = SystemAppearance.resolved(themeChoice)
        if colorScheme != next {
            colorScheme = next
        }
        if SystemAppearance.windowsNeedUpdate(for: colorScheme) {
            SystemAppearance.apply(colorScheme)
        }
    }

    private func watchAppearance() {
        guard appearanceObserver == nil else { return }
        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshScheme()
            }
        }
    }

    func reload() {
        running = RunningStore.load()
        completed = DailyNote.loadAll(in: notesDirectory)
    }

    func chooseNotesDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "选择"
        panel.message = "选择存放每日记录的文件夹"
        panel.directoryURL = notesDirectory
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        notesDirectory = url
        UserDefaults.standard.set(url.path, forKey: NotesLocation.storageKey)
        reload()
    }

    func startDraft() {
        let title = cleanTitle(draft.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !title.isEmpty else { return }
        running.append(RunningEntry(id: UUID(), title: title, start: Date()))
        draft = ""
        errorMessage = nil
        persistRunning()
    }

    func stop(_ entry: RunningEntry) {
        do {
            try DailyNote.append(
                title: entry.title,
                start: entry.start,
                end: now,
                directory: notesDirectory
            )
            running.removeAll { $0.id == entry.id }
            persistRunning()
            completed = DailyNote.loadAll(in: notesDirectory)
            errorMessage = nil
        } catch {
            errorMessage = "没能写入日记：\(error.localizedDescription)"
        }
    }

    func shift(_ step: Int) {
        let next = range.shifting(step)
        anchor = next.anchor
    }

    func showDay(_ date: Date) {
        anchor = date
        scope = .day
        showsTimeline = true
    }

    func rotateQuote() {
        quote = QuoteLine.next()
    }

    private func persistRunning() {
        do {
            try RunningStore.save(running)
        } catch {
            errorMessage = "没能记住正在进行的任务：\(error.localizedDescription)"
        }
    }
}

struct Theme: Equatable {
    var paper: Color
    var sheet: Color
    var ink: Color
    var muted: Color
    var faint: Color
    var line: Color
    var moss: Color
    var sea: Color
    var plum: Color
    var clay: Color
    var rose: Color
    var link: Color
    var field: Color
    var fieldStroke: Color
    var row: Color
    var stopFill: Color
    var stopInk: Color
    var pill: Color
    var today: Color
    var cell: Color
    var now: Color
    var hairline: Color
    var ghostWash: Double

    static let light = Theme(
        paper: Color(red: 0.965, green: 0.945, blue: 0.910),
        sheet: Color(red: 0.984, green: 0.973, blue: 0.953),
        ink: Color(red: 0.110, green: 0.098, blue: 0.082),
        muted: Color(red: 0.486, green: 0.455, blue: 0.416),
        faint: Color(red: 0.639, green: 0.608, blue: 0.569),
        line: Color(red: 0.902, green: 0.875, blue: 0.831),
        moss: Color(red: 0.122, green: 0.416, blue: 0.259),
        sea: Color(red: 0.114, green: 0.365, blue: 0.525),
        plum: Color(red: 0.357, green: 0.298, blue: 0.518),
        clay: Color(red: 0.553, green: 0.333, blue: 0.173),
        rose: Color(red: 0.553, green: 0.239, blue: 0.302),
        link: Color(red: 0.0, green: 0.443, blue: 0.890),
        field: Color.white.opacity(0.55),
        fieldStroke: Color.black.opacity(0.12),
        row: Color.white.opacity(0.42),
        stopFill: Color.black.opacity(0.82),
        stopInk: .white,
        pill: Color(red: 0.937, green: 0.918, blue: 0.886),
        today: Color(red: 0.933, green: 0.965, blue: 0.941),
        cell: Color(red: 0.953, green: 0.933, blue: 0.902),
        now: Color(red: 0.769, green: 0.333, blue: 0.290),
        hairline: Color.black.opacity(0.08),
        ghostWash: 0.14
    )

    static let dark = Theme(
        paper: Color(red: 0.102, green: 0.094, blue: 0.086),
        sheet: Color(red: 0.149, green: 0.137, blue: 0.122),
        ink: Color(red: 0.957, green: 0.937, blue: 0.906),
        muted: Color(red: 0.733, green: 0.694, blue: 0.643),
        faint: Color(red: 0.541, green: 0.510, blue: 0.467),
        line: Color(red: 0.271, green: 0.247, blue: 0.216),
        moss: Color(red: 0.490, green: 0.808, blue: 0.635),
        sea: Color(red: 0.522, green: 0.718, blue: 0.922),
        plum: Color(red: 0.686, green: 0.663, blue: 0.925),
        clay: Color(red: 0.937, green: 0.624, blue: 0.153),
        rose: Color(red: 0.910, green: 0.627, blue: 0.675),
        link: Color(red: 0.404, green: 0.698, blue: 1),
        field: Color.white.opacity(0.08),
        fieldStroke: Color.white.opacity(0.16),
        row: Color.white.opacity(0.06),
        stopFill: Color.white.opacity(0.92),
        stopInk: Color(red: 0.110, green: 0.098, blue: 0.082),
        pill: Color.white.opacity(0.08),
        today: Color(red: 0.145, green: 0.220, blue: 0.176),
        cell: Color(red: 0.176, green: 0.161, blue: 0.141),
        now: Color(red: 0.910, green: 0.455, blue: 0.400),
        hairline: Color.white.opacity(0.10),
        ghostWash: 0.20
    )

    static func resolve(_ scheme: ColorScheme) -> Theme {
        scheme == .dark ? .dark : .light
    }

    func task(_ title: String) -> Color {
        let colors = [moss, sea, plum, clay, rose]
        let hash = title.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return colors[abs(hash) % colors.count]
    }

    static func blockFill(_ title: String) -> Color {
        let colors = [
            Color(red: 0.122, green: 0.416, blue: 0.259),
            Color(red: 0.114, green: 0.365, blue: 0.525),
            Color(red: 0.357, green: 0.298, blue: 0.518),
            Color(red: 0.553, green: 0.333, blue: 0.173),
            Color(red: 0.553, green: 0.239, blue: 0.302)
        ]
        let hash = title.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return colors[abs(hash) % colors.count]
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.light
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

enum NotesLocation {
    static let storageKey = "riji.notesDirectory"

    static func resolve() -> URL {
        if let saved = UserDefaults.standard.string(forKey: storageKey), !saved.isEmpty {
            return URL(fileURLWithPath: saved, isDirectory: true)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Documents/Sankai-Vault/每日小记", isDirectory: true),
            home.appendingPathComponent("Documents/每日小记", isDirectory: true)
        ]
        if let existing = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return existing
        }
        return candidates[1]
    }
}

enum ThemeChoice: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "自动"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

enum SystemAppearance {
    static let choiceKey = "riji.themeChoice"

    static var storedChoice: ThemeChoice {
        ThemeChoice(rawValue: UserDefaults.standard.string(forKey: choiceKey) ?? "") ?? .system
    }

    static var systemScheme: ColorScheme {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" ? .dark : .light
    }

    static func resolved(_ choice: ThemeChoice) -> ColorScheme {
        switch choice {
        case .system: return systemScheme
        case .light: return .light
        case .dark: return .dark
        }
    }

    static var nsAppearance: NSAppearance? {
        appearance(for: resolved(storedChoice))
    }

    static func appearance(for scheme: ColorScheme) -> NSAppearance? {
        NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
    }

    static func windowsNeedUpdate(for scheme: ColorScheme) -> Bool {
        let name = appearance(for: scheme)?.name
        return NSApp.windows.contains { $0.appearance?.name != name }
    }

    static func apply(_ scheme: ColorScheme) {
        let appearance = appearance(for: scheme)
        for window in NSApp.windows {
            window.appearance = appearance
        }
    }
}

struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.appearance = nil
    }
}

struct ClearMenuWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.appearance = SystemAppearance.nsAppearance
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
