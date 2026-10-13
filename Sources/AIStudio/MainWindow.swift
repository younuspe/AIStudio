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
        HStack(spacing: 0) {
            sidebar
                .frame(width: 196)
            Divider()
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
                .frame(minWidth: 900, minHeight: 600)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(BrandTheme.background)
            }
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

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                model.selectedSection = .chat
            } label: {
                sidebarItem("Build", symbol: "sparkles", section: .chat)
            }
            .buttonStyle(.plain)
            .help("Open the builder workspace")

            Menu {
                ForEach(model.threads) { thread in
                    Button {
                        model.activeThreadID = thread.id
                        model.selectedSection = .chat
                    } label: {
                        Text(thread.title.isEmpty ? "New Chat" : thread.title)
                    }
                }
                Divider()
                Button("New Chat") {
                    model.newChat()
                    model.selectedSection = .chat
                }
            } label: {
                sidebarItem("History", symbol: "clock.arrow.circlepath", section: nil)
            }
            .menuStyle(.borderlessButton)
            .help("Open a previous conversation")

            Button {
                model.selectedSection = .generativeStudio
            } label: {
                sidebarItem("Gallery", symbol: "square.grid.2x2", section: .generativeStudio)
            }
            .buttonStyle(.plain)
            .help("Open model and image studio")

            Menu {
                Button("Projects") { model.selectedSection = .projects }
                Button("Visual Editor") { model.selectedSection = .visualEditor }
                Button("Developer Tools") { model.selectedSection = .developerTools }
            } label: {
                sidebarItem("More tools", symbol: "ellipsis.circle", section: nil)
            }
            .menuStyle(.borderlessButton)

            Spacer(minLength: 20)

            Button {
                model.selectedSection = .settings
            } label: {
                sidebarItem("Settings", symbol: "gearshape", section: .settings)
            }
            .buttonStyle(.plain)
            .help("Provider and app settings")

            Divider()
                .padding(.vertical, 8)

            HStack(spacing: 10) {
                Spacer(minLength: 0)
                if let iconURL = Bundle.main.url(forResource: "Supru", withExtension: "jpg"),
                   let supruIcon = NSImage(contentsOf: iconURL) {
                    Image(nsImage: supruIcon)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(BrandTheme.hotOrange.opacity(0.55), lineWidth: 1)
                        )
                        .shadow(color: BrandTheme.hotOrange.opacity(0.12), radius: 7)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Supru")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("App Builder")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 8)
        }
        .padding(10)
        .frame(maxHeight: .infinity)
        .background(BrandTheme.panel)
    }

    private func sidebarItem(_ title: String, symbol: String, section: MainSection?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 18)
            Text(title)
                .font(.system(size: 13, weight: section == activeSection ? .semibold : .regular))
            Spacer(minLength: 0)
        }
        .foregroundStyle(section == activeSection ? Color.white : BrandTheme.muted)
        .padding(.horizontal, 11)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(section == activeSection ? BrandTheme.hotOrange.opacity(0.14) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(section == activeSection ? BrandTheme.hotOrange.opacity(0.42) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private var topToolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                Text("My workspace")
                    .foregroundStyle(.secondary)
                Text("/")
                    .foregroundStyle(.tertiary)
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
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: 190, alignment: .trailing)

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
}
