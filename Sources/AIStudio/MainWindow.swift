import AppKit
import SwiftUI

enum MainSection: String, CaseIterable, Identifiable {
    case chat = "Chat"
    case generativeStudio = "Generative Studio"
    case projects = "Projects"
    case visualEditor = "Visual Editor"
    case developerTools = "Developer Tools"
    case settings = "Providers & Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .generativeStudio: return "sparkles"
        case .projects: return "folder"
        case .visualEditor: return "rectangle.on.rectangle"
        case .developerTools: return "terminal"
        case .settings: return "slider.horizontal.3"
        }
    }
}

struct MainWindow: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedSection) {
                Section("Workspace") {
                    Label("Chat", systemImage: MainSection.chat.symbol).tag(MainSection.chat)
                    Label("Generative Studio", systemImage: MainSection.generativeStudio.symbol).tag(MainSection.generativeStudio)
                    Label("Projects", systemImage: MainSection.projects.symbol).tag(MainSection.projects)
                    Label("Visual Editor", systemImage: MainSection.visualEditor.symbol).tag(MainSection.visualEditor)
                    Label("Developer Tools", systemImage: MainSection.developerTools.symbol).tag(MainSection.developerTools)
                }
                Section("Configuration") {
                    Label("Providers & Settings", systemImage: MainSection.settings.symbol).tag(MainSection.settings)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("AIStudio")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { model.newChat() } label: {
                        Label("New Chat", systemImage: "plus")
                    }
                    .help("Start a new conversation")
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 270)
        } detail: {
            Group {
                switch model.selectedSection ?? .chat {
                case .chat: ChatWorkspace(model: model)
                case .generativeStudio: GenerativeStudioWorkspace(model: model)
                case .projects: ProjectWorkspace(model: model)
                case .visualEditor: VisualEditorWorkspace(model: model)
                case .developerTools: DeveloperToolsWorkspace(model: model)
                case .settings: SettingsWorkspace(model: model)
                }
            }
            .frame(minWidth: 680, minHeight: 560)
        }
        .navigationSplitViewStyle(.balanced)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            model.stopProjectPreviewServer()
        }
    }
}
