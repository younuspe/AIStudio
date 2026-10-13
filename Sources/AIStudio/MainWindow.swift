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

    private var activeSection: MainSection {
        model.selectedSection ?? .chat
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 246)
            Rectangle()
                .fill(BrandTheme.border)
                .frame(width: 1)

            Group {
                switch activeSection {
                case .chat: ChatWorkspace(model: model)
                case .generativeStudio: GenerativeStudioWorkspace(model: model)
                case .projects: ProjectWorkspace(model: model)
                case .visualEditor: VisualEditorWorkspace(model: model)
                case .developerTools: DeveloperToolsWorkspace(model: model)
                case .settings: SettingsWorkspace(model: model)
                }
            }
            .frame(minWidth: 850, minHeight: 560)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BrandTheme.background)
        }
        .frame(minWidth: 1120, minHeight: 720)
        .background(BrandTheme.background)
        .preferredColorScheme(.dark)
        .tint(BrandTheme.hotOrange)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            model.stopProjectPreviewServer()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 16)

            Rectangle()
                .fill(BrandTheme.border)
                .frame(height: 1)

            Text("WORKSPACE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(BrandTheme.muted)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 8)

            VStack(spacing: 4) {
                sectionButton(.chat)
                sectionButton(.generativeStudio)
                sectionButton(.projects)
                sectionButton(.visualEditor)
                sectionButton(.developerTools)
            }
            .padding(.horizontal, 9)

            Spacer(minLength: 16)

            Rectangle()
                .fill(BrandTheme.border)
                .frame(height: 1)

            sectionButton(.settings)
                .padding(.horizontal, 9)
                .padding(.vertical, 10)

            HStack(spacing: 7) {
                Circle()
                    .fill(BrandTheme.hotOrange)
                    .frame(width: 6, height: 6)
                    .shadow(color: BrandTheme.hotOrange.opacity(0.75), radius: 5)
                Text("Supru • Ready to build")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(BrandTheme.muted)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 15)

            HStack(alignment: .center, spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(
                            LinearGradient(
                                colors: [BrandTheme.hotOrange.opacity(0.65), BrandTheme.deepRed.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .blur(radius: 8)

                    if let iconURL = Bundle.main.url(forResource: "Supru", withExtension: "jpg"),
                       let supruIcon = NSImage(contentsOf: iconURL) {
                        Image(nsImage: supruIcon)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11)
                                    .stroke(BrandTheme.hotOrange.opacity(0.75), lineWidth: 1)
                            )
                            .shadow(color: BrandTheme.hotOrange.opacity(0.38), radius: 9, x: 0, y: 0)
                    } else {
                        Image(systemName: "cat.fill")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(BrandTheme.hotOrange)
                            .frame(width: 40, height: 40)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Supru")
                        .font(.system(size: 29, weight: .black, design: .rounded))
                        .tracking(-1.0)
                        .foregroundStyle(Color(red: 0.015, green: 0.015, blue: 0.018))
                        .shadow(color: BrandTheme.hotOrange.opacity(0.95), radius: 5, x: 0, y: 0)
                        .shadow(color: BrandTheme.deepRed.opacity(0.8), radius: 13, x: 0, y: 0)
                        .shadow(color: BrandTheme.deepRed.opacity(0.42), radius: 22, x: 0, y: 0)

                    Text("App Builder")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .tracking(-0.25)
                        .foregroundStyle(BrandTheme.appBuilderGradient)
                        .shadow(color: Color.white.opacity(0.28), radius: 1.5, x: 0, y: 1)
                        .shadow(color: BrandTheme.deepRed.opacity(0.22), radius: 5, x: 0, y: 0)

                    Text("BUILD • PREVIEW • REFINE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.35)
                        .foregroundStyle(BrandTheme.muted)
                        .padding(.top, 5)
                }
            }
            .padding(.horizontal, 17)

            .padding(.top, 12)
            .padding(.bottom, 18)
        }
        .background(BrandTheme.panel)
    }

    private func sectionButton(_ section: MainSection) -> some View {
        let isSelected = activeSection == section

        return Button {
            model.selectedSection = section
        } label: {
            HStack(spacing: 11) {
                Image(systemName: section.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 19)
                    .foregroundStyle(isSelected ? BrandTheme.hotOrange : BrandTheme.muted)

                Text(section.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.70))

                Spacer(minLength: 0)

                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(BrandTheme.hotOrange)
                        .frame(width: 3, height: 19)
                        .shadow(color: BrandTheme.hotOrange.opacity(0.7), radius: 5)
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 39)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected ? BrandTheme.hotOrange.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(isSelected ? BrandTheme.hotOrange.opacity(0.38) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(section.rawValue)
    }
}
