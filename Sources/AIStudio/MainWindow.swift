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
    @State private var showPublishInfo = false

    private var activeSection: MainSection { model.selectedSection ?? .chat }

    var body: some View {
        VStack(spacing: 0) {
            topToolbar
            Divider()
            Group {
                switch activeSection {
                case .chat:
                    BuilderWorkspace(model: model)
                case .generativeStudio:
                    GenerativeStudioWorkspace(model: model)
                case .projects:
                    ProjectWorkspace(model: model)
                case .visualEditor:
                    VisualEditorWorkspace(model: model)
                case .developerTools:
                    DeveloperToolsWorkspace(model: model)
                case .settings:
                    SettingsWorkspace(model: model)
                }
            }
            .frame(minWidth: 1120, minHeight: 620)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BrandTheme.background)
            Divider()
            brandFooter
        }
        .frame(minWidth: 1320, minHeight: 760)
        .background(BrandTheme.background)
        .preferredColorScheme(.dark)
        .tint(BrandTheme.hotOrange)
        .alert("Publishing is not configured yet", isPresented: $showPublishInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your project can be exported as a ZIP now. To publish it, connect a deployment provider or deploy it using the hosting service of your choice.")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            model.stopProjectPreviewServer()
        }
    }

    private var topToolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                Text("My workspace").foregroundStyle(.secondary)
                Text("/").foregroundStyle(.tertiary)
                Text(model.workspaceURL?.lastPathComponent ?? "Untitled app")
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            .font(.system(size: 13))
            .help("Current project workspace")

            Spacer(minLength: 12)

            HStack(spacing: 6) {
                Circle()
                    .fill(model.fileIsDirty ? BrandTheme.hotOrange : Color.green)
                    .frame(width: 6, height: 6)
                Text(model.fileIsDirty ? "Unsaved changes" : (model.statusMessage ?? "All changes saved"))
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: 190, alignment: .trailing)

            Menu {
                Button("Model Playground & Image Studio") { model.selectedSection = .generativeStudio }
                Button("Projects & Files") { model.selectedSection = .projects }
                Button("Visual Editor") { model.selectedSection = .visualEditor }
                Button("Developer Tools") { model.selectedSection = .developerTools }
                Divider()
                Button("Providers & Settings") { model.selectedSection = .settings }
            } label: {
                Label("Tools", systemImage: "slider.horizontal.3")
            }
            .menuStyle(.borderlessButton)
            .help("Open additional workspaces")

            Button {
                model.newChat()
                model.selectedSection = .chat
            } label: {
                Label("Remix", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderless)
            .help("Start a fresh chat")

            Button {
                if let projectURL = model.workspaceURL, let contentView = NSApp.keyWindow?.contentView {
                    let picker = NSSharingServicePicker(items: [projectURL])
                    picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
                } else if let projectURL = model.workspaceURL {
                    NSWorkspace.shared.activateFileViewerSelecting([projectURL])
                } else {
                    model.openWorkspace(navigateToProjects: false)
                }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderless)
            .help("Share the current project folder")

            Button { showPublishInfo = true } label: {
                Label("Publish (not configured)", systemImage: "globe")
            }
            .buttonStyle(.borderless)
            .help("Publishing is unavailable until a deployment provider is configured")

            Menu {
                Button("Export project as ZIP…") { model.exportWorkspaceArchive() }
                    .disabled(model.workspaceURL == nil)
                Button("Reveal project in Finder") {
                    if let projectURL = model.workspaceURL {
                        NSWorkspace.shared.activateFileViewerSelecting([projectURL])
                    } else {
                        model.openWorkspace()
                    }
                }
                .disabled(model.workspaceURL == nil)
            } label: {
                Label("Export", systemImage: "square.and.arrow.down")
            }
            .menuStyle(.borderlessButton)

            Button {
                model.selectedSection = .settings
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Providers and settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(BrandTheme.panel)
    }

    private var brandFooter: some View {
        HStack(spacing: 8) {
            Spacer()
            if let iconURL = Bundle.main.url(forResource: "Supru", withExtension: "jpg"),
               let supruIcon = NSImage(contentsOf: iconURL) {
                Image(nsImage: supruIcon)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(BrandTheme.hotOrange.opacity(0.55), lineWidth: 1)
                    )
                    .shadow(color: BrandTheme.hotOrange.opacity(0.14), radius: 6)
            }
            Text("Supru App Builder")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))
            Spacer()
        }
        .frame(height: 38)
        .background(BrandTheme.panel)
    }
}
