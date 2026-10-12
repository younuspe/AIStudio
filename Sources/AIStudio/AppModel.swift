import AppKit
import Combine
import Foundation
import Security
import SwiftUI

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var role: String
    var content: String
    let createdAt: Date

    init(role: String, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = Date()
    }
}

struct ChatThread: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var modifiedAt: Date

    init(title: String = "New Chat", messages: [ChatMessage] = []) {
        self.id = UUID()
        self.title = title
        self.messages = messages
        self.modifiedAt = Date()
    }
}

struct ProviderConfiguration: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var baseURL: String
    var model: String

    static var defaults: [ProviderConfiguration] {
        [
            ProviderConfiguration(id: "ollama", name: "Ollama (Local)", baseURL: "http://127.0.0.1:11434/v1", model: "qwen2.5-coder:7b"),
            ProviderConfiguration(id: "openrouter", name: "OpenRouter", baseURL: "https://openrouter.ai/api/v1", model: ""),
            ProviderConfiguration(id: "nvidia", name: "NVIDIA API", baseURL: "https://integrate.api.nvidia.com/v1", model: "nvidia/nemotron-3.5-lightning-30b-a3b"),
            ProviderConfiguration(id: "openai-compatible", name: "OpenAI-compatible", baseURL: "https://api.openai.com/v1", model: "")
        ]
    }

    var keychainAccount: String { "provider.\(id)" }
    var isLocal: Bool { baseURL.lowercased().contains("localhost") || baseURL.contains("127.0.0.1") }
}

struct WorkspaceEntry: Identifiable {
    let url: URL
    let depth: Int
    let isDirectory: Bool
    var id: String { url.path }
    var name: String { url.lastPathComponent }
}

private struct PersistedState: Codable {
    var providers: [ProviderConfiguration]
    var selectedProviderID: String
    var threads: [ChatThread]
    var activeThreadID: UUID?
    var workspacePath: String?
}

private struct GeneratedProjectPayload: Decodable {
    let files: [GeneratedProjectFile]
}

private struct GeneratedProjectFile: Decodable {
    let path: String
    let content: String
}

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedSection: MainSection? = .chat
    @Published var threads: [ChatThread] = []
    @Published var activeThreadID: UUID?
    @Published var inputText = ""
    @Published var isSending = false

    @Published var providers: [ProviderConfiguration] = ProviderConfiguration.defaults
    @Published var selectedProviderID = "ollama"
    @Published var providerName = ""
    @Published var providerBaseURL = ""
    @Published var providerModel = ""
    @Published var apiKeyDraft = ""
    @Published var selectedProviderHasKey = false
    @Published var discoveredModels: [String] = []
    @Published var isFetchingModels = false

    @Published var workspaceURL: URL?
    @Published var workspaceFiles: [WorkspaceEntry] = []
    @Published var selectedFileURL: URL?
    @Published var fileContent = ""
    @Published var fileIsDirty = false
    @Published var previewFileURL: URL?
    @Published var previewRefreshID = UUID()

    @Published var projectPrompt = ""
    @Published var isGeneratingProject = false
    @Published var visualBackgroundColor = "#ffffff"
    @Published var visualTextColor = "#171717"
    @Published var visualContentWidth = 1120.0
    @Published var visualFontSize = 16.0
    @Published var visualCornerRadius = 12.0
    @Published var visualSectionSpacing = 24.0
    @Published var commandText = "git status"
    @Published var consoleOutput = "Select a project folder, then run a command you have reviewed."
    @Published var isRunningCommand = false
    @Published var statusMessage: String?
    @Published var lastError: String?

    private let fileManager = FileManager.default
    private var stateURL: URL { Self.supportDirectory.appendingPathComponent("state.json") }

    static var supportDirectory: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return root.appendingPathComponent("AIStudio", isDirectory: true)
    }

    var activeProvider: ProviderConfiguration {
        providers.first(where: { $0.id == selectedProviderID }) ?? providers.first ?? ProviderConfiguration.defaults[0]
    }

    var activeThread: ChatThread? {
        threads.first(where: { $0.id == activeThreadID })
    }

    init() {
        loadState()
        if providers.isEmpty { providers = ProviderConfiguration.defaults }
        if !providers.contains(where: { $0.id == selectedProviderID }) {
            selectedProviderID = providers.first?.id ?? "ollama"
        }
        if threads.isEmpty {
            let thread = ChatThread()
            threads = [thread]
            activeThreadID = thread.id
        } else if !threads.contains(where: { $0.id == activeThreadID }) {
            activeThreadID = threads.first?.id
        }
        if let path = loadWorkspacePath(), fileManager.fileExists(atPath: path) {
            workspaceURL = URL(fileURLWithPath: path, isDirectory: true)
        }
        loadProviderForm()
        refreshWorkspaceFiles()
    }

    func newChat() {
        let thread = ChatThread()
        threads.insert(thread, at: 0)
        activeThreadID = thread.id
        selectedSection = .chat
        lastError = nil
        saveState()
    }

    func selectThread(_ id: UUID?) {
        activeThreadID = id
        lastError = nil
        saveState()
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        if activeThreadID == nil {
            let thread = ChatThread()
            threads.insert(thread, at: 0)
            activeThreadID = thread.id
        }
        guard let targetID = activeThreadID,
              let index = threads.firstIndex(where: { $0.id == targetID }) else { return }

        threads[index].messages.append(ChatMessage(role: "user", content: text))
        if threads[index].messages.count == 1 { threads[index].title = String(text.prefix(48)) }
        threads[index].modifiedAt = Date()
        let provider = activeProvider
        let messages = threads[index].messages
        let key = KeychainStore.read(account: provider.keychainAccount) ?? ""
        inputText = ""
        isSending = true
        lastError = nil
        saveState()

        Task {
            do {
                let response = try await AIProviderClient.complete(provider: provider, apiKey: key, messages: messages)
                append(response, role: "assistant", to: targetID)
                isSending = false
                saveState()
            } catch {
                lastError = error.localizedDescription
                isSending = false
            }
        }
    }

    private func append(_ content: String, role: String, to threadID: UUID) {
        guard let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[index].messages.append(ChatMessage(role: role, content: content))
        threads[index].modifiedAt = Date()
    }

    func openWorkspace() {
        let panel = NSOpenPanel()
        panel.title = "Open a project folder"
        panel.message = "Choose a folder to browse, edit, or generate project files."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if fileIsDirty { saveCurrentFile() }
        workspaceURL = url.standardizedFileURL
        selectedFileURL = nil
        fileContent = ""
        fileIsDirty = false
        previewFileURL = nil
        refreshWorkspaceFiles()
        saveState()
        statusMessage = "Opened \(url.lastPathComponent)"
        selectedSection = .projects
    }

    func refreshWorkspaceFiles() {
        guard let root = workspaceURL else {
            workspaceFiles = []
            return
        }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue,
              let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey], options: [.skipsPackageDescendants]) else {
            workspaceFiles = []
            return
        }

        var entries: [WorkspaceEntry] = []
        let excluded = Set([".git", "node_modules", ".build", "DerivedData", ".next", "dist", "build"])
        for case let url as URL in enumerator {
            if excluded.contains(url.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = values?.isDirectory == true
            let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
            let depth = max(0, relative.split(separator: "/").count - 1)
            entries.append(WorkspaceEntry(url: url, depth: depth, isDirectory: isDirectory))
            if entries.count >= 3000 { break }
        }
        workspaceFiles = entries.sorted {
            let left = $0.url.path.replacingOccurrences(of: root.path + "/", with: "")
            let right = $1.url.path.replacingOccurrences(of: root.path + "/", with: "")
            return left.localizedStandardCompare(right) == .orderedAscending
        }
    }

    func selectFile(_ url: URL) {
        guard !url.hasDirectoryPath else { return }
        guard let root = workspaceURL, isInsideWorkspace(url, root: root) else {
            lastError = "Refused to open a file outside the selected project folder."
            return
        }
        if fileIsDirty {
            saveCurrentFile()
            if fileIsDirty { return }
        }
        do {
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) else {
                lastError = "This file is not UTF-8 text and cannot be edited in the text editor."
                return
            }
            selectedFileURL = url
            fileContent = text
            fileIsDirty = false
            lastError = nil
        } catch {
            lastError = "Could not open file: \(error.localizedDescription)"
        }
    }

    func markFileDirty() {
        if selectedFileURL != nil { fileIsDirty = true }
    }

    func saveCurrentFile() {
        guard let url = selectedFileURL, let root = workspaceURL, isInsideWorkspace(url, root: root) else {
            lastError = "Refused to save outside the selected project folder."
            return
        }
        do {
            try Data(fileContent.utf8).write(to: url, options: .atomic)
            fileIsDirty = false
            statusMessage = "Saved \(url.lastPathComponent)"
            lastError = nil
            refreshWorkspaceFiles()
            if previewFileURL?.path == url.path { previewRefreshID = UUID() }
        } catch {
            lastError = "Could not save file: \(error.localizedDescription)"
        }
    }

    func createNewFile() {
        guard let root = workspaceURL else {
            openWorkspace()
            guard workspaceURL != nil else { return }
            createNewFile()
            return
        }
        guard let relativePath = promptForPath(title: "New File", message: "Enter a path relative to the project folder (subfolders are allowed).", confirm: "Create File") else { return }
        guard let url = validatedProjectURL(relativePath, root: root) else {
            lastError = "Use a relative path inside the project folder. Paths containing '..' are not allowed."
            return
        }
        do {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard !fileManager.fileExists(atPath: url.path) else {
                lastError = "That file already exists."
                return
            }
            try Data().write(to: url, options: .atomic)
            refreshWorkspaceFiles()
            selectFile(url)
            statusMessage = "Created \(relativePath)"
        } catch {
            lastError = "Could not create file: \(error.localizedDescription)"
        }
    }

    func createNewFolder() {
        guard let root = workspaceURL else {
            openWorkspace()
            guard workspaceURL != nil else { return }
            createNewFolder()
            return
        }
        guard let relativePath = promptForPath(title: "New Folder", message: "Enter a folder path relative to the project folder.", confirm: "Create Folder") else { return }
        guard let url = validatedProjectURL(relativePath, root: root) else {
            lastError = "Use a relative path inside the project folder. Paths containing '..' are not allowed."
            return
        }
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            refreshWorkspaceFiles()
            statusMessage = "Created folder \(relativePath)"
        } catch {
            lastError = "Could not create folder: \(error.localizedDescription)"
        }
    }

    private func promptForPath(title: String, message: String, confirm: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirm)
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = title == "New Folder" ? "src/components" : "src/new-file.swift"
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let path = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    private func validatedProjectURL(_ relativePath: String, root: URL) -> URL? {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "/", omittingEmptySubsequences: true)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("/"), !trimmed.hasPrefix("~"),
              !parts.isEmpty, !parts.contains(".."), !parts.contains("."), !parts.contains(".git") else { return nil }
        let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        let url = root.appendingPathComponent(trimmed).standardizedFileURL.resolvingSymlinksInPath().standardizedFileURL
        guard url.path.hasPrefix(rootPath + "/") else { return nil }
        return url
    }

    private func isInsideWorkspace(_ url: URL, root: URL) -> Bool {
        let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        let targetPath = url.resolvingSymlinksInPath().standardizedFileURL.path
        return targetPath.hasPrefix(rootPath + "/")
    }

    func selectProvider() {
        loadProviderForm()
        saveState()
    }

    func loadProviderForm() {
        let provider = activeProvider
        providerName = provider.name
        providerBaseURL = provider.baseURL
        providerModel = provider.model
        apiKeyDraft = ""
        selectedProviderHasKey = KeychainStore.read(account: provider.keychainAccount) != nil
        discoveredModels = []
    }

    func addOpenAICompatibleProvider() {
        let id = "custom-\(UUID().uuidString.lowercased())"
        providers.append(ProviderConfiguration(id: id, name: "Custom OpenAI-compatible", baseURL: "http://127.0.0.1:11434/v1", model: ""))
        selectedProviderID = id
        loadProviderForm()
        saveState()
    }

    func saveProviderSettings() {
        guard let index = providers.firstIndex(where: { $0.id == selectedProviderID }) else { return }
        let normalizedURL = providerBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: normalizedURL), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else {
            lastError = "Enter a valid provider URL beginning with http:// or https://."
            return
        }
        let name = providerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            lastError = "Provider name cannot be empty."
            return
        }
        providers[index].name = name
        providers[index].baseURL = normalizedURL
        providers[index].model = providerModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKeyDraft.isEmpty {
            guard KeychainStore.write(apiKeyDraft, account: providers[index].keychainAccount) else {
                lastError = "macOS Keychain could not save this API key."
                return
            }
        }
        apiKeyDraft = ""
        selectedProviderHasKey = KeychainStore.read(account: providers[index].keychainAccount) != nil
        lastError = nil
        statusMessage = "Provider settings saved locally."
        saveState()
    }

    func removeStoredAPIKey() {
        KeychainStore.delete(account: activeProvider.keychainAccount)
        apiKeyDraft = ""
        selectedProviderHasKey = false
        statusMessage = "Stored API key removed from Keychain."
    }

    func fetchModels() {
        isFetchingModels = true
        lastError = nil
        let provider = ProviderConfiguration(id: selectedProviderID, name: providerName, baseURL: providerBaseURL, model: providerModel)
        let key = apiKeyDraft.isEmpty ? (KeychainStore.read(account: provider.keychainAccount) ?? "") : apiKeyDraft
        Task {
            do {
                let models = try await AIProviderClient.listModels(provider: provider, apiKey: key)
                discoveredModels = models.sorted()
                statusMessage = discoveredModels.isEmpty
                    ? "The endpoint responded, but did not return a model list."
                    : "Loaded \(discoveredModels.count) model IDs from the provider."
                isFetchingModels = false
            } catch {
                lastError = error.localizedDescription
                isFetchingModels = false
            }
        }
    }

    func useDiscoveredModel(_ modelID: String) {
        providerModel = modelID
    }

    func generateProject() {
        guard let root = workspaceURL else {
            lastError = "Open a project folder first, then generate into that folder."
            return
        }
        let requestText = projectPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestText.isEmpty, !isGeneratingProject else { return }

        let provider = activeProvider
        let key = KeychainStore.read(account: provider.keychainAccount) ?? ""
        isGeneratingProject = true
        lastError = nil
        statusMessage = "Asking the selected model to plan project files…"
        let systemPrompt = """
        You are a senior software project generator. Return ONLY one valid JSON object in this exact shape:
        {"files":[{"path":"relative/path.ext","content":"complete file contents"}]}
        Create a useful, complete project with source files, dependency manifests, configuration, and a README when appropriate.
        Do not use Markdown fences or text outside the JSON. Paths must be relative; never write secrets. Keep every path inside the project folder.
        """
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: "Generate this project in the currently selected folder: \(requestText)")
        ]

        Task {
            do {
                let response = try await AIProviderClient.complete(provider: provider, apiKey: key, messages: messages)
                guard let data = Self.extractJSON(response).data(using: .utf8) else { throw AppModelError.invalidProjectJSON }
                let payload = try JSONDecoder().decode(GeneratedProjectPayload.self, from: data)
                guard !payload.files.isEmpty, payload.files.count <= 120 else { throw AppModelError.invalidProjectSize }

                var prepared: [(URL, Data)] = []
                var totalBytes = 0
                for file in payload.files {
                    guard let url = validatedProjectURL(file.path, root: root) else { throw AppModelError.unsafeProjectPath(file.path) }
                    let content = Data(file.content.utf8)
                    guard content.count <= 1_000_000 else { throw AppModelError.fileTooLarge(file.path) }
                    totalBytes += content.count
                    guard totalBytes <= 20_000_000 else { throw AppModelError.projectTooLarge }
                    prepared.append((url, content))
                }

                let existing = prepared.filter { fileManager.fileExists(atPath: $0.0.path) }
                if !existing.isEmpty {
                    let alert = NSAlert()
                    alert.messageText = "Replace existing project files?"
                    alert.informativeText = "\(existing.count) generated file(s) already exist. Replacing them may overwrite your edits."
                    alert.addButton(withTitle: "Replace Files")
                    alert.addButton(withTitle: "Cancel")
                    guard alert.runModal() == .alertFirstButtonReturn else {
                        isGeneratingProject = false
                        statusMessage = "Project generation cancelled; existing files were not changed."
                        return
                    }
                }

                for (url, data) in prepared {
                    try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: url, options: .atomic)
                }
                projectPrompt = ""
                refreshWorkspaceFiles()
                isGeneratingProject = false
                statusMessage = "Generated and saved \(prepared.count) project files."
                selectedSection = .projects
                saveState()
            } catch {
                isGeneratingProject = false
                lastError = "Project generation failed: \(error.localizedDescription)"
            }
        }
    }

    private static func extractJSON(_ text: String) -> String {
        if let first = text.firstIndex(of: "{"), let last = text.lastIndex(of: "}"), first <= last {
            return String(text[first...last])
        }
        return text
    }

    func refreshPreview() {
        guard let root = workspaceURL else {
            lastError = "Open a project folder to preview its web output."
            return
        }
        if let selectedFileURL, selectedFileURL.pathExtension.lowercased() == "html" {
            previewFileURL = selectedFileURL
        } else {
            let candidates = ["index.html", "src/index.html", "public/index.html"]
            previewFileURL = candidates.map { root.appendingPathComponent($0) }
                .first(where: { fileManager.fileExists(atPath: $0.path) })
        }
        guard previewFileURL != nil else {
            lastError = "No HTML file was found. Select an HTML file in Projects first."
            return
        }
        previewRefreshID = UUID()
        lastError = nil
        selectedSection = .visualEditor
    }

    func applyVisualSettings() {
        guard let root = workspaceURL, let htmlURL = previewFileURL,
              htmlURL.pathExtension.lowercased() == "html",
              isInsideWorkspace(htmlURL, root: root) else {
            lastError = "Open a local project and choose an HTML page before applying visual changes."
            return
        }
        do {
            let original = try String(contentsOf: htmlURL, encoding: .utf8)
            let background = Self.sanitizedHexColor(visualBackgroundColor, fallback: "#ffffff")
            let foreground = Self.sanitizedHexColor(visualTextColor, fallback: "#171717")
            let styleBlock = """
            <style data-aistudio-visual-editor="true">
            :root { --aistudio-page-background: \(background); --aistudio-text-color: \(foreground); --aistudio-content-width: \(Int(visualContentWidth))px; --aistudio-font-size: \(Int(visualFontSize))px; --aistudio-corner-radius: \(Int(visualCornerRadius))px; --aistudio-section-spacing: \(Int(visualSectionSpacing))px; }
            html, body { background: var(--aistudio-page-background) !important; color: var(--aistudio-text-color) !important; font-size: var(--aistudio-font-size) !important; }
            body { max-width: var(--aistudio-content-width); margin-left: auto; margin-right: auto; padding: 24px; box-sizing: border-box; }
            section, article, main { margin-block: var(--aistudio-section-spacing); }
            button, input, textarea, select { border-radius: var(--aistudio-corner-radius); }
            </style>
            """
            let pattern = #"(?is)<style\s+data-aistudio-visual-editor\s*=\s*["']true["'][^>]*>.*?</style>"#
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(original.startIndex..., in: original)
            var updated = regex.stringByReplacingMatches(in: original, range: range, withTemplate: "")
            if let headEnd = updated.range(of: "</head>", options: .caseInsensitive) {
                updated.insert(contentsOf: styleBlock + "\n", at: headEnd.lowerBound)
            } else if let bodyOpen = updated.range(of: "<body", options: .caseInsensitive),
                      let bodyEnd = updated[bodyOpen.lowerBound...].firstIndex(of: ">") {
                updated.insert(contentsOf: "\n" + styleBlock + "\n", at: updated.index(after: bodyEnd))
            } else {
                updated = styleBlock + "\n" + updated
            }
            try Data(updated.utf8).write(to: htmlURL, options: .atomic)
            if selectedFileURL?.path == htmlURL.path {
                fileContent = updated
                fileIsDirty = false
            }
            previewRefreshID = UUID()
            statusMessage = "Applied visual settings to \(htmlURL.lastPathComponent) and saved the changes."
            lastError = nil
            refreshWorkspaceFiles()
        } catch {
            lastError = "Could not save visual changes: \(error.localizedDescription)"
        }
    }

    private static func sanitizedHexColor(_ value: String, fallback: String) -> String {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        guard [3, 6].contains(text.count), text.allSatisfy({ $0.isHexDigit }) else { return fallback }
        return "#" + text
    }

    func runCommand() {
        guard let root = workspaceURL else {
            lastError = "Open a project folder before running a command."
            return
        }
        let command = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty, !isRunningCommand else { return }
        isRunningCommand = true
        lastError = nil
        consoleOutput = "$ \(command)\nRunning in \(root.path)…\n"
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            process.currentDirectoryURL = root
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                var output = String(decoding: data, as: UTF8.self)
                if output.count > 100_000 { output = "… earlier output truncated …\n" + String(output.suffix(100_000)) }
                output += "\n[exit code: \(process.terminationStatus)]"
                DispatchQueue.main.async {
                    self.consoleOutput = output
                    self.isRunningCommand = false
                    self.statusMessage = "Command finished with exit code \(process.terminationStatus)."
                }
            } catch {
                DispatchQueue.main.async {
                    self.consoleOutput = "Could not start command: \(error.localizedDescription)"
                    self.isRunningCommand = false
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    private func loadWorkspacePath() -> String? {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else { return nil }
        return state.workspacePath
    }

    private func loadState() {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else { return }
        providers = state.providers
        selectedProviderID = state.selectedProviderID
        threads = state.threads
        activeThreadID = state.activeThreadID
    }

    private func saveState() {
        do {
            try fileManager.createDirectory(at: Self.supportDirectory, withIntermediateDirectories: true)
            let state = PersistedState(providers: providers, selectedProviderID: selectedProviderID, threads: threads, activeThreadID: activeThreadID, workspacePath: workspaceURL?.path)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(state).write(to: stateURL, options: .atomic)
        } catch {
            lastError = "Could not save local app state: \(error.localizedDescription)"
        }
    }
}

private enum AppModelError: LocalizedError {
    case invalidProjectJSON
    case invalidProjectSize
    case unsafeProjectPath(String)
    case fileTooLarge(String)
    case projectTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidProjectJSON: return "The model did not return valid JSON. Try a smaller or more specific project request."
        case .invalidProjectSize: return "The model returned no files or more than the 120-file limit."
        case .unsafeProjectPath(let path): return "Refused to write an unsafe path: \(path)"
        case .fileTooLarge(let path): return "Generated file exceeds the 1 MB limit: \(path)"
        case .projectTooLarge: return "Generated project exceeds the 20 MB total size limit."
        }
    }
}

private enum KeychainStore {
    private static let service = "com.aistudio.desktop.providers"

    static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func write(_ value: String, account: String) -> Bool {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
            return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private enum AIProviderClient {
    private struct ModelList: Decodable {
        struct Item: Decodable { let id: String }
        let data: [Item]
    }

    private struct CompletionResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }

    static func complete(provider: ProviderConfiguration, apiKey: String, messages: [ChatMessage]) async throws -> String {
        guard let url = endpoint(baseURL: provider.baseURL, suffix: "/chat/completions") else {
            throw ProviderError.invalidURL(provider.baseURL)
        }
        guard !provider.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProviderError.missingModel
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        if provider.id == "openrouter" { request.setValue("AIStudio", forHTTPHeaderField: "X-Title") }
        let body: [String: Any] = [
            "model": provider.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": false,
            "temperature": 0.7
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.httpStatus(http.statusCode, Self.errorDetail(from: data))
        }
        let decoded = try JSONDecoder().decode(CompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else { throw ProviderError.emptyResponse }
        return content
    }

    static func listModels(provider: ProviderConfiguration, apiKey: String) async throws -> [String] {
        guard let url = endpoint(baseURL: provider.baseURL, suffix: "/models") else {
            throw ProviderError.invalidURL(provider.baseURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 45
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.httpStatus(http.statusCode, Self.errorDetail(from: data))
        }
        let decoded = try JSONDecoder().decode(ModelList.self, from: data)
        return decoded.data.map(\.id)
    }

    private static func endpoint(baseURL: String, suffix: String) -> URL? {
        var normalized = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalized.hasSuffix("/") { normalized.removeLast() }
        if normalized.hasSuffix("/chat/completions") { normalized.removeLast("/chat/completions".count) }
        if normalized.hasSuffix("/models") { normalized.removeLast("/models".count) }
        return URL(string: normalized + suffix)
    }

    private static func errorDetail(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = object["error"] as? String { return error }
            if let errorObject = object["error"] as? [String: Any],
               let message = errorObject["message"] as? String { return message }
            if let message = object["message"] as? String { return message }
        }
        return String(data: data.prefix(900), encoding: .utf8) ?? "No response details were returned."
    }
}

private enum ProviderError: LocalizedError {
    case invalidURL(String)
    case missingModel
    case invalidResponse
    case emptyResponse
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value): return "Invalid provider URL: \(value)"
        case .missingModel: return "Choose a model ID in Providers & Settings first."
        case .invalidResponse: return "The provider returned an invalid HTTP response."
        case .emptyResponse: return "The provider response did not contain assistant text."
        case .httpStatus(let status, let detail): return "Provider returned HTTP \(status): \(detail)"
        }
    }
}
