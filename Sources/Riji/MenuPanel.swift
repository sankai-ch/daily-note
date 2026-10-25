import AppKit
import RijiCore
import SwiftUI

struct MenuLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: model.running.isEmpty ? "clock" : "clock.fill")
            if !model.running.isEmpty {
                Circle()
                    .fill(Color(red: 0.49, green: 0.81, blue: 0.64))
                    .frame(width: 6, height: 6)
            }
            if !model.menuTitle.isEmpty {
                Text(model.menuTitle)
            }
        }
        .onAppear { model.bootstrap() }
    }
}

struct MenuPanel: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @FocusState private var fieldFocused: Bool

    private var theme: Theme { Theme.resolve(model.colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            field
            Text("回车新开一件。正在跑的不会被停掉。")
                .font(.system(size: 11))
                .foregroundStyle(theme.muted)
                .padding(.horizontal, 2)

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.rose)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: { model.chooseNotesDirectory() }) {
                Text("日记 · \(model.notesDirectory.lastPathComponent)")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.faint)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .help(model.notesDirectory.path)

            if !model.running.isEmpty {
                VStack(spacing: 6) {
                    ForEach(model.running) { entry in
                        runningRow(entry)
                    }
                }
            }

            Rectangle()
                .fill(theme.hairline)
                .frame(height: 0.5)

            Picker("主题", selection: $model.themeChoice) {
                ForEach(ThemeChoice.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)

            HStack {
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "workbench")
                }) {
                    Text("打开工作台")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.link)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                Button(action: { NSApp.terminate(nil) }) {
                    Text("退出")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.faint)
                }
                .buttonStyle(.plain)
            }

            Text(model.quote)
                .font(.system(size: 15))
                .foregroundStyle(theme.ink.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 320)
        .background(VisualEffect(material: .popover))
        .background(ClearMenuWindow())
        .environment(\.theme, theme)
        .preferredColorScheme(model.colorScheme)
        .background(PanelOpen { model.rotateQuote() })
        .onAppear {
            fieldFocused = true
            model.refreshScheme()
        }
    }

    private var field: some View {
        ZStack(alignment: .leading) {
            if model.draft.isEmpty {
                Text("准备做什么，回车开始")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.faint)
                    .padding(.horizontal, 10)
                    .allowsHitTesting(false)
            }
            TextField("", text: $model.draft)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .focused($fieldFocused)
                .onSubmit { model.startDraft() }
        }
        .background(theme.field, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(fieldFocused ? theme.link.opacity(0.85) : theme.fieldStroke, lineWidth: fieldFocused ? 1.5 : 0.5)
        )
        .shadow(color: fieldFocused ? theme.link.opacity(0.28) : .clear, radius: 3, y: 0)
    }

    private func runningRow(_ entry: RunningEntry) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                Text("\(logClock(entry.start)) 开始 · \(clockText(from: entry.start, to: model.now))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(theme.muted)
            }
            Spacer(minLength: 8)
            Button(action: { model.stop(entry) }) {
                Text("停止")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.stopInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(theme.stopFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(theme.row, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(theme.fieldStroke, lineWidth: 0.5)
        )
    }

    private func logClock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private struct PanelOpen: NSViewRepresentable {
    var onOpen: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = PanelOpenView()
        view.onOpen = onOpen
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? PanelOpenView)?.onOpen = onOpen
    }

    final class PanelOpenView: NSView {
        var onOpen: (() -> Void)?
        private var visibleObserver: NSKeyValueObservation?
        private var keyObserver: NSObjectProtocol?
        private var lastOpen = Date.distantPast

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            visibleObserver = nil
            if let keyObserver {
                NotificationCenter.default.removeObserver(keyObserver)
                self.keyObserver = nil
            }
            guard let window else { return }
            visibleObserver = window.observe(\.isVisible, options: [.new]) { [weak self] window, _ in
                guard window.isVisible else { return }
                self?.fire()
            }
            keyObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.fire()
            }
            if window.isVisible {
                fire()
            }
        }

        private func fire() {
            let now = Date()
            guard now.timeIntervalSince(lastOpen) > 0.35 else { return }
            lastOpen = now
            DispatchQueue.main.async { [weak self] in
                self?.onOpen?()
            }
        }

        deinit {
            if let keyObserver {
                NotificationCenter.default.removeObserver(keyObserver)
            }
        }
    }
}
