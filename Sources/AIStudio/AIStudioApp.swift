import SwiftUI

@main
struct AIStudioApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            MainWindow(model: model)
                .frame(minWidth: 1120, minHeight: 720)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") { model.newChat() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Open Project…") { model.openWorkspace() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("New File…") { model.createNewFile() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
    }
}
