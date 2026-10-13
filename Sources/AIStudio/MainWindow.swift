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
            workspaceToolbar
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
            .frame(minWidth: 1000, minHeight: 600)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BrandTheme.background)
        }
        .frame(minWidth: 1120, minHeight: 720)
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
            Button {
                model.selectedSection = .chat
            } label: {
                Label("Back to start", systemImage: "arrow.left")
            }
            .buttonStyle(.borderless)
            .help("Return to the unified builder workspace")

            Spacer(minLength: 12)

            HStack(spacing: 9) {
                if let iconURL = Bundle.main.url(forResource: "Supru", withExtension: "jpg"),
                   let supruIcon = NSImage(contentsOf: iconURL) {
                    Image(nsImage: supruIcon)
                        .resizable().scaledToFill().frame(width: 23, height: 23)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(BrandTheme.hotOrange.opacity(0.7), lineWidth: 1))
                }
                Text("Supru AI")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
            }

            Spacer(minLength: 12)

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
                Label("Publish", systemImage: "globe")
            }
            .buttonStyle(.borderless)
            .help("Publishing setup information")

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

    private var workspaceToolbar: some View {
        HStack(spacing: 5) {
            ForEach(MainSection.allCases) { section in
                Button {
                    model.selectedSection = section
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: section.symbol)
                            .font(.system(size: 12, weight: .medium))
                        Text(section.rawValue)
                            .font(.system(size: 11, weight: activeSection == section ? .semibold : .regular))
                    }
                    .foregroundStyle(activeSection == section ? Color.white : BrandTheme.muted)
                    .padding(.horizontal, 11)
                    .frame(height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(activeSection == section ? BrandTheme.hotOrange.opacity(0.14) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(activeSection == section ? BrandTheme.hotOrange.opacity(0.42) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help(section.rawValue)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(BrandTheme.hotOrange).frame(width: 6, height: 6)
                Text(model.statusMessage ?? (model.workspaceURL == nil ? "Ready" : model.workspaceURL!.lastPathComponent))
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: 230, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(BrandTheme.background)
    }
}
