import SwiftUI

@main
struct RijiApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuPanel(model: model)
        } label: {
            MenuLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("日计", id: "workbench") {
            WorkbenchView(model: model)
        }
        .defaultSize(width: 980, height: 740)
        .windowResizability(.contentMinSize)
    }
}
