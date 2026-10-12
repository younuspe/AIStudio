import AppKit
import SwiftUI
import WebKit

struct ChatWorkspace: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Chats").font(.headline)
                    Spacer()
                    Button { model.newChat() } label: { Image(systemName: "plus") }
                        .buttonStyle(.borderless)
                        .help("New chat")
                }
                .padding(12)
                Divider()
                List(selection: $model.activeThreadID) {
                    ForEach(model.threads) { thread in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(thread.title.isEmpty ? "New Chat" : thread.title).lineLimit(1)
                            Text(thread.modifiedAt, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .tag(thread.id as UUID?)
                        .padding(.vertical, 3)
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 170, idealWidth: 220, maxWidth: 280)

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: model.activeProvider.isLocal ? "desktopcomputer" : "network")
                        .foregroundStyle(.secondary)
                    Text(model.activeProvider.name).fontWeight(.medium)
                    Text("·")
                    Text(model.activeProvider.model.isEmpty ? "Choose a model" : model.activeProvider.model)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button("Provider Settings") { model.selectedSection = .settings }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            if let thread = model.activeThread, thread.messages.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 36))
                                        .foregroundStyle(.secondary)
                                    Text("What are you building?")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    Text("Chat with a local Ollama model or configure any OpenAI-compatible provider.")
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: 420)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 100)
                            }
                            if let thread = model.activeThread {
                                ForEach(thread.messages) { message in
                                    ChatMessageRow(message: message).id(message.id)
                                }
                            }
                            if model.isSending {
                                HStack(spacing: 8) {
                                    ProgressView().controlSize(.small)
                                    Text("Waiting for the model…").foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 8)
                            }
                        }
                        .padding(20)
                    }
                    .onChange(of: model.activeThread?.messages.count ?? 0) { _ in
                        guard let last = model.activeThread?.messages.last else { return }
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                if let error = model.lastError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                }
                Divider()
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Message AIStudio…", text: $model.inputText, axis: .vertical)
                        .lineLimit(1...5)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        .onSubmit { model.sendMessage() }
                    Button { model.sendMessage() } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 28))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isSending || model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("Send message")
                }
                .padding(14)
            }
            .frame(minWidth: 480)
        }
    }
}

private struct ChatMessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: message.role == "user" ? "person.crop.circle" : "sparkles")
                .font(.title3)
                .foregroundStyle(message.role == "user" ? Color.primary : Color.accentColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 5) {
                Text(message.role == "user" ? "You" : "Assistant")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(message.content)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(message.role == "user" ? Color.accentColor.opacity(0.08) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10))
    }
}

struct ProjectWorkspace: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.workspaceURL?.lastPathComponent ?? "No project open").font(.headline)
                    Text(model.workspaceURL?.path ?? "Open a local folder to browse and edit project files.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button("Open Folder…") { model.openWorkspace() }
                Button { model.createNewFile() } label: { Label("New File", systemImage: "doc.badge.plus") }
                    .disabled(model.workspaceURL == nil)
                Button { model.createNewFolder() } label: { Label("New Folder", systemImage: "folder.badge.plus") }
                    .disabled(model.workspaceURL == nil)
                Button { model.renameSelectedFile() } label: { Label("Rename", systemImage: "pencil") }
                    .disabled(model.selectedFileURL == nil)
                Button { model.deleteSelectedFile() } label: { Label("Delete", systemImage: "trash") }
                    .disabled(model.selectedFileURL == nil)
                Button { model.saveCurrentFile() } label: { Label("Save", systemImage: "square.and.arrow.down") }
                    .disabled(model.selectedFileURL == nil || !model.fileIsDirty)
                    .keyboardShortcut("s", modifiers: .command)
            }
            .padding(12)
            Divider()

            if model.workspaceURL != nil {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .bottom, spacing: 10) {
                        TextField("Describe the app or project to generate…", text: $model.projectPrompt, axis: .vertical)
                            .lineLimit(1...3)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            model.generateProject()
                        } label: {
                            if model.isGeneratingProject {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Generate Files", systemImage: "sparkles")
                            }
                        }
                        .disabled(model.isGeneratingProject || model.projectPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Text("The selected model will generate project files into this folder. Existing files trigger a confirmation before replacement.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                Divider()
            }

            if model.workspaceURL == nil {
                ContentPlaceholder(
                    symbol: "folder",
                    title: "Open a project folder",
                    message: "Browse local files, create folders, edit text files, and save changes directly to disk.",
                    buttonTitle: "Choose Folder",
                    action: { model.openWorkspace() }
                )
            } else {
                HSplitView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("FILES").font(.caption).fontWeight(.semibold)
                            Spacer()
                            Button { model.refreshWorkspaceFiles() } label: { Image(systemName: "arrow.clockwise") }
                                .buttonStyle(.borderless)
                                .help("Refresh file list")
                        }
                        .padding(10)
                        Divider()
                        List {
                            ForEach(model.workspaceFiles) { entry in
                                Button {
                                    if !entry.isDirectory { model.selectFile(entry.url) }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: entry.isDirectory ? "folder" : "doc.text")
                                            .foregroundStyle(entry.isDirectory ? Color.secondary : Color.primary)
                                        Text(String(repeating: "  ", count: entry.depth) + entry.name).lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(entry.isDirectory)
                            }
                        }
                        .listStyle(.sidebar)
                    }
                    .frame(minWidth: 190, idealWidth: 250, maxWidth: 340)

                    VStack(spacing: 0) {
                        HStack {
                            Text(model.selectedFileURL?.lastPathComponent ?? "Editor").font(.headline)
                            if model.fileIsDirty { Circle().fill(.orange).frame(width: 7, height: 7) }
                            Spacer()
                            if let url = model.selectedFileURL {
                                Text(url.pathExtension.uppercased()).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        Divider()
                        if model.selectedFileURL == nil {
                            ContentPlaceholder(
                                symbol: "doc.text",
                                title: "Select a text file",
                                message: "Choose a file from the project list to edit it. Use Save to write changes to disk.",
                                buttonTitle: nil,
                                action: {}
                            )
                        } else {
                            TextEditor(text: $model.fileContent)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .onChange(of: model.fileContent) { _ in model.markFileDirty() }
                        }
                    }
                    .frame(minWidth: 360)
                }
            }
            StatusFooter(model: model)
        }
    }
}

struct VisualEditorWorkspace: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Visual Editor & Preview").font(.headline)
                    Text("Native controls around a preview of your own local HTML project.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Open Project…") { model.openWorkspace() }
                Button { model.refreshPreview() } label: { Label("Reload Preview", systemImage: "arrow.clockwise") }
                    .disabled(model.workspaceURL == nil)
            }
            .padding(12)
            Divider()

            if let url = model.previewFileURL {
                HSplitView {
                    LocalHTMLPreview(fileURL: url, refreshID: model.previewRefreshID)
                        .frame(minWidth: 420, minHeight: 400)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Selected page").font(.headline)
                        Label(url.lastPathComponent, systemImage: "globe")
                        Text(url.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        Divider()
                        Text("Visual properties").font(.headline)
                        Picker("Common target", selection: $model.visualTargetSelector) {
                            Text("Page body").tag("body")
                            Text("Header").tag("header")
                            Text("Navigation").tag("nav")
                            Text("Main area").tag("main")
                            Text("Section").tag("section")
                            Text("Heading").tag("h1")
                            Text("Button").tag("button")
                            Text("Hero class").tag(".hero")
                            Text("Root ID").tag("#root")
                        }
                        .pickerStyle(.menu)
                        TextField("CSS selector (e.g. .hero or #header)", text: $model.visualTargetSelector)
                            .textFieldStyle(.roundedBorder)
                        TextField("Background color (hex)", text: $model.visualBackgroundColor)
                            .textFieldStyle(.roundedBorder)
                        TextField("Text color (hex)", text: $model.visualTextColor)
                            .textFieldStyle(.roundedBorder)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Content width: \(Int(model.visualContentWidth)) px")
                            Slider(value: $model.visualContentWidth, in: 600...1600, step: 40)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Font size: \(Int(model.visualFontSize)) px")
                            Slider(value: $model.visualFontSize, in: 12...28, step: 1)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Corner radius: \(Int(model.visualCornerRadius)) px")
                            Slider(value: $model.visualCornerRadius, in: 0...40, step: 1)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Section spacing: \(Int(model.visualSectionSpacing)) px")
                            Slider(value: $model.visualSectionSpacing, in: 0...80, step: 4)
                        }
                        Button {
                            model.applyVisualSettings()
                        } label: {
                            Label("Apply and Save", systemImage: "paintbrush.pointed")
                        }
                        .disabled(model.previewFileURL == nil)
                        Text("The app saves these CSS properties into the selected HTML file. Use Projects for more detailed source editing.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Edit source in Projects") {
                            model.selectFile(url)
                            model.selectedSection = .projects
                        }
                    }
                    .padding(16)
                    .frame(minWidth: 220, maxWidth: 300, alignment: .topLeading)
                }
            } else {
                ContentPlaceholder(
                    symbol: "rectangle.on.rectangle",
                    title: "Preview a local web project",
                    message: "Open a project, select an HTML file in Projects, then return here and reload the preview. AIStudio's own interface remains native SwiftUI.",
                    buttonTitle: "Open Project",
                    action: { model.openWorkspace() }
                )
            }
            StatusFooter(model: model)
        }
    }
}



struct DeveloperToolsWorkspace: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Developer Tools").font(.headline)
                    Text(model.workspaceURL?.path ?? "Choose a project folder to run build, test, and Git commands.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button("Open Project…") { model.openWorkspace() }
            }
            .padding(12)
            Divider()

            if model.workspaceURL == nil {
                ContentPlaceholder(
                    symbol: "terminal",
                    title: "Open a project first",
                    message: "Commands run locally as your macOS user, with the selected project folder as the working directory.",
                    buttonTitle: "Choose Project",
                    action: { model.openWorkspace() }
                )
            } else {
                HStack(spacing: 10) {
                    TextField("Command to run in the selected project folder", text: $model.commandText)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { model.runCommand() }
                    Button {
                        model.runCommand()
                    } label: {
                        if model.isRunningCommand {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Run", systemImage: "play.fill")
                        }
                    }
                    .disabled(model.isRunningCommand || model.commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(12)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        presetButton("Git status", command: "git status --short --branch")
                        presetButton("npm test", command: "npm test")
                        presetButton("npm build", command: "npm run build")
                        presetButton("Swift test", command: "swift test")
                        presetButton("Swift build", command: "swift build")
                    }
                    .padding(.horizontal, 12)
                }
                Text("Commands execute only after you press Run or a preset. Review commands before running; generated code is not executed automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                Divider()
                ScrollView {
                    Text(model.consoleOutput)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
            }

            StatusFooter(model: model)
        }
    }

    private func presetButton(_ title: String, command: String) -> some View {
        Button(title) {
            model.commandText = command
            model.runCommand()
        }
        .disabled(model.isRunningCommand)
    }
}

private struct LocalHTMLPreview: NSViewRepresentable {
    let fileURL: URL
    let refreshID: UUID

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        if context.coordinator.lastRefreshID != refreshID || context.coordinator.lastPath != fileURL.path {
            context.coordinator.lastRefreshID = refreshID
            context.coordinator.lastPath = fileURL.path
            view.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastRefreshID = UUID()
        var lastPath = ""
    }
}

private struct ContentPlaceholder: View {
    let symbol: String
    let title: String
    let message: String
    let buttonTitle: String?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 34)).foregroundStyle(.secondary)
            Text(title).font(.title3).fontWeight(.semibold)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            if let buttonTitle { Button(buttonTitle, action: action).padding(.top, 4) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }
}

private struct StatusFooter: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if let status = model.statusMessage {
            Divider()
            HStack {
                Image(systemName: "checkmark.circle").foregroundStyle(.secondary)
                Text(status).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { model.statusMessage = nil } label: {
                    Image(systemName: "xmark").font(.caption2)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
    }
}
