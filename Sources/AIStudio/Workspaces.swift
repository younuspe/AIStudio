import AppKit
import SwiftUI
import WebKit

private enum ChatComposerMode: String, CaseIterable, Identifiable {
    case chat = "Chat"
    case build = "Build App"
    var id: String { rawValue }
}

struct ChatWorkspace: View {
    @ObservedObject var model: AppModel
    @State private var composerMode: ChatComposerMode = .chat
    @StateObject private var voiceInput = VoiceInputController()
    @State private var draftBeforeDictation = ""

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
                                    Text("Chat, experiment with models, or build a complete app from a description. Generated source files are saved into the project folder you choose.")
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: 420)
                                    HStack(spacing: 8) {
                                        Button("Build a dashboard") {
                                            composerMode = .build
                                            model.inputText = "Build a responsive business dashboard with navigation, reusable components, realistic sample data, accessible layouts, and a README with run instructions. Implement functional interactions, not a static mockup."
                                        }
                                        Button("Create a landing page") {
                                            composerMode = .build
                                            model.inputText = "Build a complete responsive product landing page with a hero, feature sections, pricing, testimonials, FAQ, and working mobile navigation. Include source files, npm scripts, tests where suitable, and run instructions."
                                        }
                                        Button("Make a task manager") {
                                            composerMode = .build
                                            model.inputText = "Build a functional task manager with create/edit/delete, status filters, search, local persistence, responsive design, form validation, and tests. Include the complete project folder and README."
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 100)
                            }
                            if let thread = model.activeThread {
                                ForEach(thread.messages) { message in
                                    ChatMessageRow(message: message).id(message.id)
                                }
                            }
                            if model.isSending || model.isGeneratingProject {
                                HStack(spacing: 8) {
                                    ProgressView().controlSize(.small)
                                    Text(model.isGeneratingProject ? (model.statusMessage ?? "Planning and generating app files…") : "Waiting for the model…")
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
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
                if !model.chatAttachments.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(model.chatAttachments, id: \.path) { url in
                                HStack(spacing: 5) {
                                    Image(systemName: "doc.text")
                                    Text(url.lastPathComponent).lineLimit(1)
                                    Button {
                                        model.removeChatAttachment(url)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.secondary.opacity(0.13), in: Capsule())
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                    }
                }
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Picker("Composer mode", selection: $composerMode) {
                            ForEach(ChatComposerMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 190)
                        Menu {
                            Button("Explain or debug code") {
                                composerMode = .chat
                                model.inputText = "Inspect the relevant code, identify the root cause, explain your changes, and verify the fix using an appropriate test."
                            }
                            Button("Build a full dashboard") {
                                composerMode = .build
                                model.inputText = "Build a production-minded responsive dashboard with reusable components, realistic data, loading/empty/error states, accessibility, functional controls, tests where suitable, and complete run instructions."
                            }
                            Button("Build a CRUD application") {
                                composerMode = .build
                                model.inputText = "Create a functional CRUD web app with create/read/update/delete, search, filtering, validation, persistent local data, responsive UI, useful error states, tests, and a README. Include the full project folder and working run/build scripts."
                            }
                            Button("Build an e-commerce storefront") {
                                composerMode = .build
                                model.inputText = "Build a responsive e-commerce storefront with product listing, search/filter, product details, cart quantity controls, correct totals, and a working demo checkout flow. Include accessible UI, tests where suitable, full source, and honest documentation of demo-only parts."
                            }
                            Button("Build a portfolio") {
                                composerMode = .build
                                model.inputText = "Create a complete responsive portfolio site with home, projects, about, validated contact form, working mobile navigation, accessible polished UI, and README run instructions. Make every visible control functional."
                            }
                            Button("Improve the open app") {
                                composerMode = .build
                                model.inputText = "Inspect the selected project folder and improve the existing application without discarding working features. Preserve the current architecture, implement the requested change, and include build/test steps."
                            }
                        } label: {
                            Label("Prompt starters", systemImage: "lightbulb")
                        }
                        .menuStyle(.borderlessButton)
                        Spacer(minLength: 0)
                        if voiceInput.isRecording {
                            Text("Listening…").font(.caption).foregroundStyle(.red)
                        }
                        if model.workspaceURL != nil {
                            Button {
                                if model.previewServerURL != nil {
                                    model.previewRefreshID = UUID()
                                } else {
                                    model.startProjectPreviewServer()
                                }
                            } label: {
                                Label(model.previewServerURL == nil ? "Run Preview" : "Refresh Preview",
                                      systemImage: model.previewServerURL == nil ? "play.rectangle" : "arrow.clockwise")
                            }
                            .disabled(model.isStartingPreviewServer || model.isRunningCommand)
                        }
                    }
                    HStack(alignment: .bottom, spacing: 10) {
                        Button { model.attachContextFiles() } label: {
                            Image(systemName: "paperclip").font(.system(size: 18))
                        }
                        .buttonStyle(.plain)
                        .help("Attach source or text files as context")

                        TextField(composerMode == .build ? "Describe the app you want to build…" : "Message AIStudio…",
                                  text: $model.inputText, axis: .vertical)
                            .lineLimit(1...5)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                            .onSubmit { submitComposer() }

                        Button {
                            if voiceInput.isRecording {
                                voiceInput.stop()
                            } else {
                                draftBeforeDictation = model.inputText
                                voiceInput.start()
                            }
                        } label: {
                            Image(systemName: voiceInput.isRecording ? "stop.circle.fill" : "mic.circle")
                                .font(.system(size: 27))
                                .foregroundStyle(voiceInput.isRecording ? Color.red : Color.primary)
                        }
                        .buttonStyle(.plain)
                        .help(voiceInput.isRecording ? "Stop voice input" : "Dictate a prompt")
                        .disabled(model.isSending || model.isGeneratingProject)

                        Button { submitComposer() } label: {
                            Text("Meow!")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 17)
                                .frame(height: 39)
                                .background(
                                    LinearGradient(
                                        colors: [BrandTheme.hotOrange, BrandTheme.deepRed],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    in: Capsule()
                                )
                                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                                .shadow(color: BrandTheme.deepRed.opacity(0.38), radius: 10, x: 0, y: 0)
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isSending || model.isGeneratingProject ||
                                  model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(model.isSending || model.isGeneratingProject ||
                                 model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.48 : 1)
                        .help(composerMode == .build ? "Create app from this prompt" : "Send message")
                    }
                    if let voiceError = voiceInput.errorMessage, !voiceError.isEmpty {
                        Text(voiceError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14)
                .onChange(of: voiceInput.transcript) { transcript in
                    guard !transcript.isEmpty else { return }
                    let prefix = draftBeforeDictation.trimmingCharacters(in: .whitespacesAndNewlines)
                    model.inputText = prefix.isEmpty ? transcript : prefix + " " + transcript
                }
            }
            .frame(minWidth: 480)

            if model.workspaceURL != nil {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("App Preview").font(.headline)
                            Text(model.previewServerURL?.absoluteString ?? "Local project")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        if model.previewServerURL != nil {
                            Button { model.previewRefreshID = UUID() } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .help("Refresh live preview")
                        }
                    }
                    .padding(12)
                    Divider()
                    if let url = model.previewServerURL {
                        LocalURLPreview(url: url, refreshID: model.previewRefreshID)
                    } else if let fileURL = model.previewFileURL, let root = model.workspaceURL {
                        LocalHTMLPreview(fileURL: fileURL, accessRoot: root, refreshID: model.previewRefreshID)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "macwindow.on.rectangle")
                                .font(.system(size: 34)).foregroundStyle(.secondary)
                            Text("Your app preview appears here").font(.headline)
                            Text("Create an app in Build App mode, review its files, then run the local development server. The preview stays inside AIStudio beside your chat.")
                                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            Button { model.startProjectPreviewServer() } label: {
                                Label("Start Local Preview", systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isStartingPreviewServer || model.isPreviewServerRunning)
                            if model.isStartingPreviewServer { ProgressView("Starting development server…") }
                            if !model.previewServerLog.isEmpty {
                                Text(model.previewServerLog)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled).lineLimit(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    if let root = model.workspaceURL,
                       FileManager.default.fileExists(atPath: root.appendingPathComponent("package.json").path) {
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Build verification").font(.caption.weight(.semibold))
                                Text("Installs declared dependencies, then runs build and test scripts.")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                model.commandText = "npm install && npm run build && npm test --if-present"
                                model.selectedSection = .developerTools
                                model.runCommand()
                            } label: {
                                Label("Install, Build & Test", systemImage: "checkmark.seal")
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isRunningCommand || model.isGeneratingProject)
                        }
                        .padding(10)
                    }
                }
                .frame(minWidth: 300, idealWidth: 430)
            }
        }
        .onChange(of: voiceInput.errorMessage) { error in
            if let error, !error.isEmpty { model.statusMessage = error }
        }
    }

    private func submitComposer() {
        guard !model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if composerMode == .build {
            if model.createProjectFromChat(model.inputText) { composerMode = .chat }
        } else {
            model.sendMessage()
        }
    }
}

private struct ChatMessageRow: View {
    let message: ChatMessage

    private var formattedContent: AttributedString {
        (try? AttributedString(markdown: message.content)) ?? AttributedString(message.content)
    }

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
                Text(formattedContent)
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
                if let projectURL = model.workspaceURL {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([projectURL])
                    }
                }
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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Visual Editor & Preview").font(.headline)
                        Text("Preview static HTML or run the selected web project's local dev server.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Open Project…") { model.openWorkspace() }
                    Button { model.refreshPreview() } label: { Label("Reload", systemImage: "arrow.clockwise") }
                        .disabled(model.workspaceURL == nil)
                }
                HStack(spacing: 8) {
                    TextField("Preview command", text: $model.previewServerCommand)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                        .help("Use the project's dev command and bind it to 127.0.0.1. Commands execute as your macOS user.")
                    TextField("http://127.0.0.1:5173", text: $model.previewServerURLText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                        .font(.system(.caption, design: .monospaced))
                    if model.isStartingPreviewServer {
                        ProgressView().controlSize(.small)
                        Button("Starting…") { model.stopProjectPreviewServer() }
                    } else if model.isPreviewServerRunning {
                        Button { model.stopProjectPreviewServer() } label: {
                            Label("Stop Server", systemImage: "stop.fill")
                        }
                    } else {
                        Button { model.startProjectPreviewServer() } label: {
                            Label("Run Preview", systemImage: "play.fill")
                        }
                        .disabled(model.workspaceURL == nil)
                    }
                }
                if model.isPreviewServerRunning || !model.previewServerLog.isEmpty {
                    HStack {
                        Image(systemName: model.isPreviewServerRunning ? "circle.fill" : "terminal")
                            .foregroundStyle(model.isPreviewServerRunning ? Color.green : Color.secondary)
                            .font(.system(size: 8))
                        Text(model.isPreviewServerRunning
                             ? (model.previewServerURL?.absoluteString ?? "Local preview server starting…")
                             : "Previous preview server log available")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Show Log") {
                            model.consoleOutput = model.previewServerLog
                            model.selectedSection = .developerTools
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding(12)
            Divider()

            if let liveURL = model.previewServerURL {
                HSplitView {
                    LocalURLPreview(url: liveURL, refreshID: model.previewRefreshID)
                        .frame(minWidth: 420, minHeight: 400)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Live project preview").font(.headline)
                        Label(liveURL.absoluteString, systemImage: "network")
                            .font(.caption)
                            .textSelection(.enabled)
                        Text("The page is served by the development command shown above. AIStudio's own interface remains native SwiftUI.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
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
                        Text("These controls save a CSS override into the project's HTML entry page, including most Vite projects. For more advanced component changes, edit source files in Projects.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Open Projects") { model.selectedSection = .projects }
                    }
                    .padding(16)
                    .frame(minWidth: 220, maxWidth: 300, alignment: .topLeading)
                }
            } else if let url = model.previewFileURL, let accessRoot = model.workspaceURL {
                HSplitView {
                    LocalHTMLPreview(fileURL: url, accessRoot: accessRoot, refreshID: model.previewRefreshID)
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

private struct LocalURLPreview: NSViewRepresentable {
    let url: URL
    let refreshID: UUID

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: url))
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        if context.coordinator.lastRefreshID != refreshID || context.coordinator.lastURL != url {
            context.coordinator.lastRefreshID = refreshID
            context.coordinator.lastURL = url
            view.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastRefreshID = UUID()
        var lastURL: URL?

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard navigationAction.targetFrame?.isMainFrame == true,
                  let target = navigationAction.request.url,
                  let host = target.host?.lowercased() else {
                decisionHandler(.allow)
                return
            }
            if target.scheme?.lowercased() == "http",
               !["127.0.0.1", "localhost", "::1"].contains(host) {
                decisionHandler(.cancel)
                return
            }
            if ["https", "file", "javascript"].contains(target.scheme?.lowercased() ?? "") {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

private struct LocalHTMLPreview: NSViewRepresentable {
    let fileURL: URL
    let accessRoot: URL
    let refreshID: UUID

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.loadFileURL(fileURL, allowingReadAccessTo: accessRoot)
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        if context.coordinator.lastRefreshID != refreshID || context.coordinator.lastPath != fileURL.path {
            context.coordinator.lastRefreshID = refreshID
            context.coordinator.lastPath = fileURL.path
            view.loadFileURL(fileURL, allowingReadAccessTo: accessRoot)
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
