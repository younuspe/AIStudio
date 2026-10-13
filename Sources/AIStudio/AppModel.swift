import UniformTypeIdentifiers
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
            ProviderConfiguration(id: "gemini", name: "Google Gemini API", baseURL: "https://generativelanguage.googleapis.com/v1beta", model: ""),
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

private struct GeneratedProjectPlan: Decodable {
    let files: [GeneratedProjectPlanFile]
}

private struct GeneratedProjectPlanFile: Decodable {
    let path: String
    let purpose: String
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
    @Published var chatAttachments: [URL] = []
    @Published var isSending = false

    @Published var providers: [ProviderConfiguration] = ProviderConfiguration.defaults
    @Published var selectedProviderID = "ollama"
    @Published var providerName = ""
    @Published var providerBaseURL = ""
    @Published var providerModel = ""
    @Published var apiKeyDraft = ""
    @Published var selectedProviderHasKey = false
    @Published var discoveredModels: [String] = []
    @Published var showOnlyFreeModels = false
    @Published var isFetchingModels = false

    @Published var workspaceURL: URL?
    @Published var workspaceFiles: [WorkspaceEntry] = []
    @Published var selectedFileURL: URL?
    @Published var fileContent = ""
    @Published var fileIsDirty = false
    private var savedFileContent = ""
    @Published var previewFileURL: URL?
    @Published var previewRefreshID = UUID()
    @Published var previewServerCommand = "npm run dev -- --host 127.0.0.1 --port 5173 --strictPort"
    @Published var previewServerURLText = "http://127.0.0.1:5173"
    @Published var previewServerURL: URL?
    @Published var isStartingPreviewServer = false
    @Published var isPreviewServerRunning = false
    @Published var previewServerLog = ""

    @Published var imagePrompt = ""
    @Published var imageModelID = "gpt-image-1"
    @Published var imageSize = "1024x1024"
    @Published var imageSourceURL: URL?
    @Published var generatedImageData: Data?
    @Published var isGeneratingImage = false

    @Published var projectPrompt = ""
    @Published var isGeneratingProject = false
    @Published var visualBackgroundColor = "#ffffff"
    @Published var visualTextColor = "#171717"
    @Published var visualTargetSelector = "body"
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
    private var previewServerProcess: Process?
    private var previewServerLogHandle: FileHandle?
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

    var visibleDiscoveredModels: [String] {
        showOnlyFreeModels ? discoveredModels.filter { $0.lowercased().hasSuffix(":free") } : discoveredModels
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

    func attachContextFiles() {
        let panel = NSOpenPanel()
        panel.title = "Attach files to chat"
        panel.message = "Choose source or text files to include as context. Selected content is sent to your chosen model; do not attach secrets or API-key files."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        let requestedCount = chatAttachments.count + panel.urls.count
        var combined = chatAttachments
        for url in panel.urls {
            let standardized = url.standardizedFileURL
            if !combined.contains(where: { $0.standardizedFileURL == standardized }) && combined.count < 8 {
                combined.append(standardized)
            }
        }
        chatAttachments = combined
        if combined.count < requestedCount {
            statusMessage = "A maximum of eight unique files can be attached to one message."
        }
    }

    func removeChatAttachment(_ url: URL) {
        chatAttachments.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
    }

    private func buildMessageWithFileContext(_ prompt: String, files: [URL]) -> String {
        guard !files.isEmpty else { return prompt }
        var remainingCharacters = 120_000
        var blocks: [String] = []
        for url in files {
            guard remainingCharacters > 0 else {
                blocks.append("[Remaining attached files omitted because the context size limit was reached.]")
                break
            }
            do {
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                let totalBytes = (attributes[.size] as? NSNumber)?.intValue ?? 0
                let handle = try FileHandle(forReadingFrom: url)
                let data: Data
                do {
                    data = try handle.read(upToCount: 512_000) ?? Data()
                    try handle.close()
                } catch {
                    try? handle.close()
                    throw error
                }
                guard !data.isEmpty, totalBytes > 0 else {
                    blocks.append("FILE: \(url.path)\n[File is empty or unreadable as text.]")
                    continue
                }
                let body = String(decoding: data, as: UTF8.self)
                let excerpt = String(body.prefix(min(body.count, remainingCharacters)))
                remainingCharacters -= excerpt.count
                blocks.append("FILE: \(url.path)\n--- BEGIN FILE CONTENT ---\n\(excerpt)\n--- END FILE CONTENT ---")
                if excerpt.count < body.count || totalBytes > data.count {
                    blocks.append("[File content truncated to keep the request within a safe context limit.]")
                }
            } catch {
                blocks.append("FILE: \(url.path)\n[Could not read file: \(error.localizedDescription)]")
            }
        }
        let instruction = prompt.isEmpty ? "Please review the attached files." : prompt
        return instruction + "\n\nAttached file context:\n" + blocks.joined(separator: "\n\n")
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!text.isEmpty || !chatAttachments.isEmpty), !isSending else { return }
        if activeThreadID == nil {
            let thread = ChatThread()
            threads.insert(thread, at: 0)
            activeThreadID = thread.id
        }
        guard let targetID = activeThreadID,
              let index = threads.firstIndex(where: { $0.id == targetID }) else { return }

        let submittedText = text.isEmpty ? "Please review the attached files." : text
        let attachmentURLs = chatAttachments
        threads[index].messages.append(ChatMessage(role: "user", content: submittedText))
        if threads[index].messages.count == 1 { threads[index].title = String(submittedText.prefix(48)) }
        threads[index].modifiedAt = Date()
        let provider = activeProvider
        var messages = threads[index].messages
        if let lastIndex = messages.indices.last, !attachmentURLs.isEmpty {
            messages[lastIndex] = ChatMessage(role: "user", content: buildMessageWithFileContext(submittedText, files: attachmentURLs))
        }
        let key = KeychainStore.read(account: provider.keychainAccount) ?? ""
        inputText = ""
        chatAttachments = []
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

    func exportWorkspaceArchive() {
        guard let root = workspaceURL else {
            lastError = "Open a project folder before exporting."
            return
        }
        let panel = NSSavePanel()
        panel.title = "Export Project as ZIP"
        panel.nameFieldStringValue = "\(root.lastPathComponent).zip"
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", root.path, destination.path]
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw NSError(domain: "SupruExport", code: Int(process.terminationStatus),
                              userInfo: [NSLocalizedDescriptionKey: "The ZIP export process failed with status \(process.terminationStatus)."])
            }
            statusMessage = "Exported project to \(destination.lastPathComponent)."
            lastError = nil
        } catch {
            lastError = "Project export failed: \(error.localizedDescription)"
        }
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
        if fileIsDirty {
            saveCurrentFile()
            guard !fileIsDirty else { return }
        }
        if previewServerProcess?.isRunning == true {
            stopProjectPreviewServer()
        }
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
            savedFileContent = text
            fileContent = text
            fileIsDirty = false
            lastError = nil
        } catch {
            lastError = "Could not open file: \(error.localizedDescription)"
        }
    }

    func markFileDirty() {
        guard selectedFileURL != nil else { return }
        fileIsDirty = fileContent != savedFileContent
    }

    func saveCurrentFile() {
        guard let url = selectedFileURL, let root = workspaceURL, isInsideWorkspace(url, root: root) else {
            lastError = "Refused to save outside the selected project folder."
            return
        }
        do {
            try Data(fileContent.utf8).write(to: url, options: .atomic)
            savedFileContent = fileContent
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

    func renameSelectedFile() {
        guard let url = selectedFileURL, let root = workspaceURL, isInsideWorkspace(url, root: root) else {
            lastError = "Select a file inside the open project before renaming."
            return
        }
        if fileIsDirty {
            saveCurrentFile()
            if fileIsDirty { return }
        }
        guard let newPath = promptForPath(title: "Rename File", message: "Enter a new relative path inside this project.", confirm: "Rename"),
              let destination = validatedProjectURL(newPath, root: root) else {
            lastError = "Use a relative path inside the project folder."
            return
        }
        guard destination.path != url.resolvingSymlinksInPath().standardizedFileURL.path else { return }
        guard !fileManager.fileExists(atPath: destination.path) else {
            lastError = "A file or folder already exists at that path."
            return
        }
        do {
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: url, to: destination)
            selectedFileURL = destination
            fileIsDirty = false
            if previewFileURL?.path == url.path {
                previewFileURL = destination
                previewRefreshID = UUID()
            }
            refreshWorkspaceFiles()
            statusMessage = "Renamed file to \(newPath)"
            lastError = nil
        } catch {
            lastError = "Could not rename file: \(error.localizedDescription)"
        }
    }

    func deleteSelectedFile() {
        guard let url = selectedFileURL, let root = workspaceURL, isInsideWorkspace(url, root: root) else {
            lastError = "Select a file inside the open project before deleting."
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete \(url.lastPathComponent)?"
        alert.informativeText = fileIsDirty
            ? "This permanently removes the file and discards unsaved editor changes."
            : "This permanently removes the selected file from the project folder."
        alert.addButton(withTitle: "Delete File")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try fileManager.removeItem(at: url)
            if previewFileURL?.path == url.path { previewFileURL = nil }
            selectedFileURL = nil
            fileContent = ""
            savedFileContent = ""
            fileIsDirty = false
            refreshWorkspaceFiles()
            statusMessage = "Deleted \(url.lastPathComponent)"
            lastError = nil
        } catch {
            lastError = "Could not delete file: \(error.localizedDescription)"
        }
    }

    private func promptForPath(title: String, message: String, confirm: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirm)
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = title == "New Folder" ? "src/components" : (title == "Rename File" ? "src/renamed-file.swift" : "src/new-file.swift")
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
        showOnlyFreeModels = false
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

    func chooseImageSource() {
        let panel = NSOpenPanel()
        panel.title = "Choose an image to edit"
        panel.message = "Choose a local image file. Its contents will be sent to the selected provider's image-edit endpoint."
        panel.allowedContentTypes = [.image]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK else { return }
        imageSourceURL = panel.url
        generatedImageData = nil
        lastError = nil
    }

    func clearImageSource() {
        imageSourceURL = nil
    }

    func generateImage() {
        let prompt = imagePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isGeneratingImage else {
            if prompt.isEmpty { lastError = "Enter a prompt before generating an image." }
            return
        }
        let modelID = imageModelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelID.isEmpty else {
            lastError = "Enter an image model ID supported by your selected provider."
            return
        }
        let provider = activeProvider
        let key = KeychainStore.read(account: provider.keychainAccount) ?? ""
        let source = imageSourceURL
        let size = imageSize
        isGeneratingImage = true
        generatedImageData = nil
        lastError = nil
        statusMessage = source == nil ? "Requesting image generation from \(provider.name)…" : "Requesting an edit of \(source!.lastPathComponent)…"

        Task {
            do {
                let data = try await AIProviderClient.generateImage(
                    provider: provider,
                    apiKey: key,
                    modelID: modelID,
                    prompt: prompt,
                    size: size,
                    sourceImageURL: source
                )
                guard NSImage(data: data) != nil else {
                    throw ProviderError.invalidImageResponse
                }
                generatedImageData = data
                isGeneratingImage = false
                selectedSection = .generativeStudio
                statusMessage = source == nil ? "Image generated. Save a copy to disk when ready." : "Image edit generated. Save a copy to disk when ready."
            } catch {
                isGeneratingImage = false
                lastError = "Image request failed: \(error.localizedDescription)"
            }
        }
    }

    func saveGeneratedImage() {
        guard let data = generatedImageData, let image = NSImage(data: data),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            lastError = "The generated image could not be converted to PNG."
            return
        }
        let panel = NSSavePanel()
        panel.title = "Save generated image"
        panel.nameFieldStringValue = "Supru-App-Builder-Generated.png"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try pngData.write(to: url, options: .atomic)
            statusMessage = "Saved image to \(url.path)"
            lastError = nil
        } catch {
            lastError = "Could not save image: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func createProjectFromChat(_ rawPrompt: String) -> Bool {
        let prompt = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isGeneratingProject else {
            if prompt.isEmpty { lastError = "Describe the app you want to create first." }
            return false
        }

        if workspaceURL == nil {
            let panel = NSOpenPanel()
            panel.title = "Choose the project folder for your new app"
            panel.message = "Choose an empty folder, or create a new folder in this dialog. Generated source files will be written into this location."
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let url = panel.url else {
                statusMessage = "App creation cancelled. Your prompt is still available in chat."
                return false
            }
            workspaceURL = url.standardizedFileURL
            refreshWorkspaceFiles()
            saveState()
        }

        if activeThreadID == nil {
            let thread = ChatThread()
            threads.insert(thread, at: 0)
            activeThreadID = thread.id
        }
        guard let targetID = activeThreadID,
              let index = threads.firstIndex(where: { $0.id == targetID }) else {
            lastError = "Could not select the active conversation."
            return false
        }

        let previousContext = threads[index].messages.suffix(8).map { message in
            "\(message.role == "user" ? "User" : "Assistant"): \(message.content)"
        }.joined(separator: "\n\n")
        threads[index].messages.append(ChatMessage(role: "user", content: prompt))
        if threads[index].messages.count == 1 {
            threads[index].title = String(prompt.prefix(48))
        }
        threads[index].modifiedAt = Date()
        let context = previousContext.isEmpty ? "" : "\n\nRelevant recent chat context:\n\(previousContext)"
        projectPrompt = """
        Build a complete, working application from this request.
        User requirements:
        \(prompt)
        \(context)
        """
        inputText = ""
        chatAttachments = []
        selectedSection = .chat
        lastError = nil
        statusMessage = "Starting app generation in \(workspaceURL?.lastPathComponent ?? "the selected folder")…"
        saveState()
        generateProject(replyTo: targetID)
        return true
    }

    func generateProject(replyTo replyThreadID: UUID? = nil) {
        guard let root = workspaceURL else {
            lastError = "Open a project folder first, then generate into that folder."
            return
        }
        let rawProjectRequest = projectPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawProjectRequest.isEmpty, !isGeneratingProject else { return }
        refreshWorkspaceFiles()
        let existingSourceContext = buildExistingProjectContext(root: root)
        let isIncrementalProjectUpdate = !existingSourceContext.isEmpty
        let requestText = isIncrementalProjectUpdate
            ? """
              User request:
              \(rawProjectRequest)

              Existing project source context (read-only reference; preserve unrelated files and behaviors):
              \(existingSourceContext)
              """
            : rawProjectRequest

        let provider = activeProvider
        let key = KeychainStore.read(account: provider.keychainAccount) ?? ""
        isGeneratingProject = true
        lastError = nil
        statusMessage = "Planning a complete project file tree…"

        Task {
            do {
                let planSystem: String
                if isIncrementalProjectUpdate {
                    planSystem = """
                    You are a senior software engineer modifying an EXISTING application.
                    Return ONLY JSON with this shape:
                    {"files":[{"path":"relative/path.ext","purpose":"what needs to change"}]}
                    Inspect the supplied source context and make a minimal, targeted plan for the user's requested change.
                    Include ONLY files that actually need to be created or modified. Do not recreate the app scaffold,
                    replace unrelated files, rename the architecture, remove existing working features, or invent unjustified files.
                    Preserve existing conventions, dependencies, and design. Keep every path relative.
                    Do not output Markdown fences or explanation outside JSON.
                    """
                } else {
                    planSystem = """
                    You are a staff-level software architect planning a complete, runnable application that is maintainable beyond a demo.
                    Return ONLY one valid JSON object with this exact shape:
                    {"files":[{"path":"relative/path.ext","purpose":"what this file implements"}]}
                    Plan 1–60 purposeful files. Separate UI, domain/state, data access, and API/service concerns when complexity warrants it.
                    Include the real application UI, functional state and interactions, dependency manifest, runtime/build configuration,
                    README, and meaningful tests for important behavior. Honor the user's requested stack; if none is specified, use
                    React + TypeScript + Vite for a local web app. Add a real backend, persistence layer, API routes, and validation
                    when the requirements need them; never pretend a remote service or database exists when it is not implemented.
                    Specify loading, empty, success, and error states; accessible keyboard/focus behavior; responsive layouts; validated
                    inputs; and clear module boundaries. Every visible control must have a real action, not a placeholder handler.
                    Include test/build scripts and practical run instructions. Avoid unnecessary abstractions, duplicate files, secrets,
                    binary assets, lockfiles, and generated output. Keep every path relative and return JSON only, without Markdown fences.
                    """
                }
                let planReply = try await AIProviderClient.complete(
                    provider: provider,
                    apiKey: key,
                    messages: [
                        ChatMessage(role: "system", content: planSystem),
                        ChatMessage(role: "user", content: "Project requirements:\n\(requestText)\n\nReturn the proposed project file plan as JSON.")
                    ]
                )
                guard let planData = Self.extractJSON(planReply).data(using: .utf8) else {
                    throw AppModelError.invalidProjectJSON
                }
                let plan = try JSONDecoder().decode(GeneratedProjectPlan.self, from: planData)
                guard !plan.files.isEmpty, plan.files.count <= 60 else {
                    throw AppModelError.invalidProjectPlan
                }

                var plannedPaths = Set<String>()
                for item in plan.files {
                    let normalized = Self.normalizeProjectPath(item.path)
                    guard !normalized.isEmpty,
                          plannedPaths.insert(normalized.lowercased()).inserted,
                          validatedProjectURL(normalized, root: root) != nil else {
                        throw AppModelError.unsafeProjectPath(item.path)
                    }
                }

                var generatedFiles: [GeneratedProjectFile] = []
                var offset = 0
                let batchSize = 3
                while offset < plan.files.count {
                    let end = min(offset + batchSize, plan.files.count)
                    let batch = Array(plan.files[offset..<end])
                    let batchList = batch.map { "- \($0.path): \($0.purpose)" }.joined(separator: "\n")
                    statusMessage = "Generating project files \(offset + 1)–\(end) of \(plan.files.count)…"

                    let fileSystemPrompt: String
                    if isIncrementalProjectUpdate {
                        fileSystemPrompt = """
                        You are a senior software engineer carefully modifying an existing application.
                        Return ONLY valid JSON in this shape:
                        {"files":[{"path":"relative/path.ext","content":"complete replacement file content"}]}
                        Use the supplied existing source context. Return complete contents for ONLY the planned files in this batch.
                        Preserve unrelated behavior, conventions, APIs, accessibility, tests, and dependencies. Do not create
                        placeholders or rewrite unrelated code. New behavior must be implemented, not merely described.
                        Return every requested path exactly once, do not add unrequested paths, do not use Markdown fences,
                        and do not place explanatory text outside the JSON object.
                        """
                    } else {
                        fileSystemPrompt = """
                        You are a staff-level engineer implementing production-minded source files for a real application.
                        Return ONLY valid JSON in this shape:
                        {"files":[{"path":"relative/path.ext","content":"complete file content"}]}
                        Generate complete contents for every requested file with valid JSON escaping and consistent imports, types,
                        routes, data contracts, and scripts across the batch. Implement the actual behavior described by each file's
                        purpose; never substitute mock-only handlers, dead buttons, TODOs, or success messages for unfinished work.
                        Handle loading, empty, validation, failure, and retry states. Use accessible semantic controls, keyboard support,
                        responsive layouts, and safe handling of untrusted input. Keep secrets out of source and browser bundles.
                        Use real persistence/API behavior when specified; otherwise clearly implement a useful local mode without
                        claiming an external backend exists. Include meaningful tests for critical logic when test files are requested,
                        and ensure package scripts accurately match the generated project. Return every requested path exactly once,
                        add no unrequested paths, use no Markdown fences, and put no explanation outside the JSON object.
                        """
                    }
                    let fileReply = try await AIProviderClient.complete(
                        provider: provider,
                        apiKey: key,
                        messages: [
                            ChatMessage(role: "system", content: fileSystemPrompt),
                            ChatMessage(
                                role: "user",
                                content: """
                                Overall project requirements:
                                \(requestText)

                                Generate complete file content for this batch:
                                \(batchList)

                                Ensure imports, paths, commands, and package scripts are mutually consistent.
                                """
                            )
                        ]
                    )
                    guard let fileData = Self.extractJSON(fileReply).data(using: .utf8) else {
                        throw AppModelError.invalidProjectJSON
                    }
                    let decoded = try JSONDecoder().decode(GeneratedProjectPayload.self, from: fileData)
                    var returnedPaths = Set<String>()
                    for item in decoded.files {
                        let normalized = Self.normalizeProjectPath(item.path)
                        guard let planned = batch.first(where: {
                            Self.normalizeProjectPath($0.path) == normalized
                        }) else {
                            throw AppModelError.unrequestedProjectPath(item.path)
                        }
                        guard returnedPaths.insert(normalized).inserted else {
                            throw AppModelError.duplicateProjectPath(item.path)
                        }
                        generatedFiles.append(GeneratedProjectFile(path: planned.path, content: item.content))
                    }
                    let expectedPaths = Set(batch.map { Self.normalizeProjectPath($0.path) })
                    guard returnedPaths == expectedPaths else {
                        let missing = batch
                            .filter { !returnedPaths.contains(Self.normalizeProjectPath($0.path)) }
                            .map(\.path)
                            .joined(separator: ", ")
                        throw AppModelError.incompleteProjectBatch(missing)
                    }
                    offset = end
                }

                var prepared: [(URL, Data)] = []
                var totalBytes = 0
                var finalPaths = Set<String>()
                for file in generatedFiles {
                    guard let url = validatedProjectURL(file.path, root: root) else {
                        throw AppModelError.unsafeProjectPath(file.path)
                    }
                    guard finalPaths.insert(url.path.lowercased()).inserted else {
                        throw AppModelError.duplicateProjectPath(file.path)
                    }
                    let data = Data(file.content.utf8)
                    guard data.count <= 1_000_000 else { throw AppModelError.fileTooLarge(file.path) }
                    totalBytes += data.count
                    guard totalBytes <= 20_000_000 else { throw AppModelError.projectTooLarge }
                    prepared.append((url, data))
                }

                var existingBackups: [String: Data] = [:]
                var existingPaths: [URL] = []
                for (url, _) in prepared where fileManager.fileExists(atPath: url.path) {
                    var isDirectory: ObjCBool = false
                    guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
                        throw AppModelError.targetIsDirectory(url.path)
                    }
                    existingBackups[url.path] = try Data(contentsOf: url)
                    existingPaths.append(url)
                }

                if !existingPaths.isEmpty {
                    let alert = NSAlert()
                    alert.messageText = "Replace existing project files?"
                    alert.informativeText = "\(existingPaths.count) generated file(s) already exist. Replacing them may overwrite your edits."
                    alert.addButton(withTitle: "Replace Files")
                    alert.addButton(withTitle: "Cancel")
                    guard alert.runModal() == .alertFirstButtonReturn else {
                        isGeneratingProject = false
                        statusMessage = "Project generation cancelled; existing files were not changed."
                        return
                    }
                }

                var writtenPaths: [URL] = []
                do {
                    for (url, data) in prepared {
                        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try data.write(to: url, options: .atomic)
                        writtenPaths.append(url)
                    }
                } catch {
                    for url in writtenPaths.reversed() {
                        if let backup = existingBackups[url.path] {
                            try? backup.write(to: url, options: .atomic)
                        } else {
                            try? fileManager.removeItem(at: url)
                        }
                    }
                    throw error
                }

                projectPrompt = ""
                refreshWorkspaceFiles()
                isGeneratingProject = false
                statusMessage = "Generated and saved \(prepared.count) project files."
                selectedSection = replyThreadID == nil ? .projects : .chat
                if let replyThreadID {
                    let listedFiles = prepared.prefix(40).map { "- \($0.0.path.replacingOccurrences(of: root.path + "/", with: ""))" }.joined(separator: "\n")
                    let extra = prepared.count > 40 ? "\n- …and \(prepared.count - 40) more file(s)" : ""
                    let summary = """
                    ## App files generated

                    Successfully wrote \(prepared.count) project file(s) to:

                    \(root.path)

                    \(listedFiles)\(extra)

                    **Next:** Open the Preview pane to run the application locally. Review generated scripts and dependencies before running them. File generation is not proof that the app builds or functions correctly; use Install, Build & Test to verify a Node-based web app.
                    """
                    append(summary, role: "assistant", to: replyThreadID)
                }
                saveState()
            } catch {
                isGeneratingProject = false
                lastError = "Project generation failed: \(error.localizedDescription)"
                if let replyThreadID {
                    append("## App generation failed\n\n\(error.localizedDescription)", role: "assistant", to: replyThreadID)
                    saveState()
                }
            }
        }
    }

    private func buildExistingProjectContext(root: URL) -> String {
        let allowedExtensions = Set([
            "ts", "tsx", "js", "jsx", "mjs", "cjs", "html", "css", "scss",
            "json", "md", "txt", "py", "rs", "go", "java", "kt", "c", "h",
            "hpp", "cpp", "swift", "toml", "yaml", "yml", "xml", "sql", "sh"
        ])
        let excludedNames = Set([
            ".env", ".env.local", ".env.production", "credentials.json",
            "secrets.json", "service-account.json", "id_rsa", "id_ed25519"
        ])
        var remainingCharacters = 60_000
        var blocks: [String] = []
        var includedFiles = 0

        for entry in workspaceFiles where !entry.isDirectory {
            guard remainingCharacters > 0, includedFiles < 32,
                  isInsideWorkspace(entry.url, root: root) else { continue }
            let url = entry.url.standardizedFileURL
            let fileName = url.lastPathComponent.lowercased()
            let fileExtension = url.pathExtension.lowercased()
            guard !excludedNames.contains(fileName),
                  !fileName.hasPrefix(".env."),
                  !fileName.contains("secret"),
                  !fileName.contains("credential"),
                  !["pem", "key", "p12", "pfx", "mobileprovision"].contains(fileExtension),
                  allowedExtensions.contains(fileExtension) else { continue }

            do {
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
                guard size > 0, size <= 200_000 else { continue }
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { continue }
                let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
                let excerptLimit = min(12_000, remainingCharacters)
                let excerpt = String(text.prefix(excerptLimit))
                blocks.append("FILE: \(relative)\n--- BEGIN EXISTING SOURCE ---\n\(excerpt)\n--- END EXISTING SOURCE ---")
                remainingCharacters -= excerpt.count
                includedFiles += 1
                if excerpt.count < text.count {
                    blocks.append("[Existing source context was truncated to stay within the request-size limit.]")
                    break
                }
            } catch {
                continue
            }
        }
        return blocks.joined(separator: "\n\n")
    }

    private static func normalizeProjectPath(_ value: String) -> String {
        var path = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while path.hasPrefix("./") { path.removeFirst(2) }
        return path
    }

    private static func extractJSON(_ text: String) -> String {
        if let first = text.firstIndex(of: "{"), let last = text.lastIndex(of: "}"), first <= last {
            return String(text[first...last])
        }
        return text
    }

    func refreshPreview() {
        if isPreviewServerRunning, previewServerURL != nil {
            previewRefreshID = UUID()
            lastError = nil
            statusMessage = "Reloading live project preview."
            selectedSection = .visualEditor
            return
        }
        guard let root = workspaceURL else {
            lastError = "Open a project folder to preview its output."
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
            lastError = "No static HTML file was found. Start the project's development server below to preview a React/Vite app."
            return
        }
        previewRefreshID = UUID()
        lastError = nil
        selectedSection = .visualEditor
    }

    func startProjectPreviewServer() {
        guard let root = workspaceURL else {
            lastError = "Open a project folder before starting its preview server."
            return
        }
        guard previewServerProcess?.isRunning != true else {
            statusMessage = "The project preview server is already running."
            return
        }

        let command = previewServerCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlText = previewServerURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty,
              let url = URL(string: urlText),
              url.scheme?.lowercased() == "http",
              let host = url.host?.lowercased(),
              ["127.0.0.1", "localhost", "::1"].contains(host),
              let port = url.port, (1...65535).contains(port) else {
            lastError = "Use a command and a loopback preview URL such as http://127.0.0.1:5173."
            return
        }

        do {
            let logURL = Self.supportDirectory.appendingPathComponent("project-preview.log")
            try fileManager.createDirectory(at: Self.supportDirectory, withIntermediateDirectories: true)
            try Data().write(to: logURL, options: .atomic)
            let logHandle = try FileHandle(forWritingTo: logURL)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", "exec " + command]
            process.currentDirectoryURL = root
            var environment = ProcessInfo.processInfo.environment
            let inheritedPath = environment["PATH"] ?? ""
            let commonPaths = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
            environment["PATH"] = commonPaths + (inheritedPath.isEmpty ? "" : ":" + inheritedPath)
            environment["HOST"] = "127.0.0.1"
            environment["PORT"] = String(port)
            environment["BROWSER"] = "none"
            environment["TERM"] = "xterm-256color"
            process.environment = environment
            process.standardOutput = logHandle
            process.standardError = logHandle

            process.terminationHandler = { [weak self] child in
                DispatchQueue.main.async {
                    guard let self,
                          self.previewServerProcess?.processIdentifier == child.processIdentifier else { return }
                    self.isPreviewServerRunning = false
                    self.isStartingPreviewServer = false
                    self.previewServerURL = nil
                    self.previewServerLog = (try? String(contentsOf: logURL, encoding: .utf8)) ?? "Preview server exited."
                    self.previewServerProcess = nil
                    self.previewServerLogHandle = nil
                    if child.terminationStatus != 0 {
                        self.lastError = "Preview server exited with status \(child.terminationStatus). Review its log."
                    }
                }
            }

            try process.run()
            previewServerLogHandle = logHandle
            previewServerProcess = process
            previewServerURL = nil
            isPreviewServerRunning = true
            isStartingPreviewServer = true
            lastError = nil
            previewServerLog = "Starting: \(command)\nProject folder: \(root.path)\nPreview URL: \(url.absoluteString)\n"
            statusMessage = "Starting the project's preview server…"

            Task {
                let deadline = Date().addingTimeInterval(25)
                while Date() < deadline,
                      self.previewServerProcess?.processIdentifier == process.processIdentifier,
                      process.isRunning {
                    do {
                        var request = URLRequest(url: url)
                        request.timeoutInterval = 1.5
                        let (_, response) = try await URLSession.shared.data(for: request)
                        if response is HTTPURLResponse {
                            self.previewServerURL = url
                            self.isStartingPreviewServer = false
                            self.previewRefreshID = UUID()
                            self.lastError = nil
                            self.statusMessage = "Live project preview is ready at \(url.absoluteString)."
                            return
                        }
                    } catch {
                        // Allow time for the framework to compile and begin listening.
                    }
                    try? await Task.sleep(nanoseconds: 400_000_000)
                }

                self.isStartingPreviewServer = false
                guard self.previewServerProcess?.processIdentifier == process.processIdentifier else { return }
                self.previewServerLog = (try? String(contentsOf: logURL, encoding: .utf8)) ?? self.previewServerLog
                if process.isRunning {
                    self.lastError = "The preview server is running but did not respond within 25 seconds. Check its URL, command, and log."
                } else if self.lastError == nil {
                    self.lastError = "The preview server exited before it became ready. Check its log."
                }
            }
        } catch {
            isStartingPreviewServer = false
            isPreviewServerRunning = false
            lastError = "Could not start the project preview server: \(error.localizedDescription)"
        }
    }

    func stopProjectPreviewServer() {
        guard let process = previewServerProcess else {
            isPreviewServerRunning = false
            isStartingPreviewServer = false
            previewServerURL = nil
            return
        }
        process.terminationHandler = nil
        if process.isRunning {
            process.terminate()
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                if process.isRunning { process.interrupt() }
            }
        }
        previewServerProcess = nil
        previewServerLogHandle = nil
        isPreviewServerRunning = false
        isStartingPreviewServer = false
        previewServerURL = nil
        previewServerLog = (try? String(contentsOf: Self.supportDirectory.appendingPathComponent("project-preview.log"), encoding: .utf8)) ?? previewServerLog
        statusMessage = "Stopped the project preview server."
    }

    func applyVisualSettings() {
        guard let root = workspaceURL else {
            lastError = "Open a local project before applying visual changes."
            return
        }

        let selectedHTML: URL?
        if let selectedFileURL,
           selectedFileURL.pathExtension.lowercased() == "html",
           isInsideWorkspace(selectedFileURL, root: root) {
            selectedHTML = selectedFileURL
        } else if let previewFileURL,
                  previewFileURL.pathExtension.lowercased() == "html",
                  isInsideWorkspace(previewFileURL, root: root) {
            selectedHTML = previewFileURL
        } else {
            selectedHTML = ["index.html", "src/index.html", "public/index.html"]
                .map { root.appendingPathComponent($0) }
                .first(where: { fileManager.fileExists(atPath: $0.path) && isInsideWorkspace($0, root: root) })
        }

        guard let htmlURL = selectedHTML else {
            lastError = "No HTML entry page was found. For a React/Vite app, apply visual changes to its root index.html."
            return
        }

        do {
            let original = try String(contentsOf: htmlURL, encoding: .utf8)
            let background = Self.sanitizedHexColor(visualBackgroundColor, fallback: "#ffffff")
            let foreground = Self.sanitizedHexColor(visualTextColor, fallback: "#171717")
            let selector = Self.sanitizedCSSSelector(visualTargetSelector)
            let styleBlock = """
            <style data-aistudio-visual-editor="true">
            :root { --aistudio-page-background: \(background); --aistudio-text-color: \(foreground); --aistudio-content-width: \(Int(visualContentWidth))px; --aistudio-font-size: \(Int(visualFontSize))px; --aistudio-corner-radius: \(Int(visualCornerRadius))px; --aistudio-section-spacing: \(Int(visualSectionSpacing))px; }
            html, body { background: var(--aistudio-page-background) !important; color: var(--aistudio-text-color) !important; font-size: var(--aistudio-font-size) !important; }
            body { margin-left: auto; margin-right: auto; padding: 24px; box-sizing: border-box; }
            \(selector) { background-color: var(--aistudio-page-background); color: var(--aistudio-text-color); max-width: var(--aistudio-content-width); font-size: var(--aistudio-font-size); border-radius: var(--aistudio-corner-radius); margin-block: var(--aistudio-section-spacing); }
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
                savedFileContent = updated
                fileIsDirty = false
            }
            previewFileURL = htmlURL
            previewRefreshID = UUID()
            statusMessage = "Applied visual settings to \(htmlURL.lastPathComponent) and saved the changes."
            lastError = nil
            refreshWorkspaceFiles()
        } catch {
            lastError = "Could not save visual changes: \(error.localizedDescription)"
        }
    }

    private static func sanitizedCSSSelector(_ value: String) -> String {
        let candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let punctuation = CharacterSet(charactersIn: "_#.- >:*[]=\"'")
        let allowed = CharacterSet.alphanumerics.union(punctuation)
        guard !candidate.isEmpty, candidate.count <= 120,
              candidate.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return "body" }
        return candidate
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
            var childEnvironment = ProcessInfo.processInfo.environment
            let inheritedPath = childEnvironment["PATH"] ?? ""
            let commonMacPaths = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
            childEnvironment["PATH"] = commonMacPaths + (inheritedPath.isEmpty ? "" : ":" + inheritedPath)
            childEnvironment["TERM"] = "xterm-256color"
            process.environment = childEnvironment
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
        var restoredProviders = state.providers
        for standard in ProviderConfiguration.defaults where !restoredProviders.contains(where: { $0.id == standard.id }) {
            restoredProviders.append(standard)
        }
        providers = restoredProviders
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
    case invalidProjectPlan
    case invalidProjectSize
    case unsafeProjectPath(String)
    case unrequestedProjectPath(String)
    case duplicateProjectPath(String)
    case incompleteProjectBatch(String)
    case targetIsDirectory(String)
    case fileTooLarge(String)
    case projectTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidProjectJSON:
            return "The model did not return valid JSON. Try again with a smaller or more specific project request."
        case .invalidProjectPlan:
            return "The model did not return a usable project plan. Try a more specific project request."
        case .invalidProjectSize:
            return "The model returned no files or exceeded the project-file limit."
        case .unsafeProjectPath(let path):
            return "Refused to write an unsafe path: \(path)"
        case .unrequestedProjectPath(let path):
            return "The model returned an unrequested file path: \(path)"
        case .duplicateProjectPath(let path):
            return "The model returned a duplicate file path: \(path)"
        case .incompleteProjectBatch(let paths):
            return "The model did not return all files in a generation batch: \(paths). Retry with a more specific request."
        case .targetIsDirectory(let path):
            return "A folder already occupies a generated file path: \(path)"
        case .fileTooLarge(let path):
            return "Generated file exceeds the 1 MB limit: \(path)"
        case .projectTooLarge:
            return "Generated project exceeds the 20 MB total size limit."
        }
    }
}

enum KeychainStore {
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

enum AIProviderClient {
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

    private struct ImageResponse: Decodable {
        struct Item: Decodable {
            let b64_json: String?
            let url: String?
        }
        let data: [Item]
    }

    static func generateImage(
        provider: ProviderConfiguration,
        apiKey: String,
        modelID: String,
        prompt: String,
        size: String,
        sourceImageURL: URL?
    ) async throws -> Data {
        if provider.id == "gemini" {
            return try await generateGeminiImage(
                provider: provider, apiKey: apiKey, modelID: modelID,
                prompt: prompt, size: size, sourceImageURL: sourceImageURL
            )
        }
        guard let endpoint = endpoint(
            baseURL: provider.baseURL,
            suffix: sourceImageURL == nil ? "/images/generations" : "/images/edits"
        ) else {
            throw ProviderError.invalidURL(provider.baseURL)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 240
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }

        if let sourceImageURL {
            let sourceData = try Data(contentsOf: sourceImageURL)
            guard !sourceData.isEmpty, sourceData.count <= 20_000_000 else {
                throw ProviderError.imageInputTooLarge
            }
            let boundary = "AIStudio-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            var body = Data()
            func appendField(_ name: String, _ value: String) {
                body.append(Data("--\(boundary)\r\n".utf8))
                body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
                body.append(Data(value.utf8))
                body.append(Data("\r\n".utf8))
            }
            appendField("model", modelID)
            appendField("prompt", prompt)
            appendField("size", size)
            let ext = sourceImageURL.pathExtension.lowercased()
            let mimeType = ext == "jpg" || ext == "jpeg" ? "image/jpeg"
                : ext == "webp" ? "image/webp"
                : ext == "heic" ? "image/heic"
                : "image/png"
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"image\"; filename=\"\(sourceImageURL.lastPathComponent)\"\r\n".utf8))
            body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
            body.append(sourceData)
            body.append(Data("\r\n--\(boundary)--\r\n".utf8))
            request.httpBody = body
        } else {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "model": modelID,
                "prompt": prompt,
                "n": 1,
                "size": size
            ])
        }

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.httpStatus(http.statusCode, Self.errorDetail(from: responseData))
        }
        guard let decoded = try? JSONDecoder().decode(ImageResponse.self, from: responseData),
              let first = decoded.data.first else {
            throw ProviderError.invalidImageResponse
        }

        if let encoded = first.b64_json, let data = Data(base64Encoded: encoded), !data.isEmpty {
            guard data.count <= 30_000_000 else { throw ProviderError.imageOutputTooLarge }
            return data
        }
        if let value = first.url, let url = URL(string: value),
           url.scheme?.lowercased() == "https", url.host != nil {
            var imageRequest = URLRequest(url: url)
            imageRequest.timeoutInterval = 60
            let (data, imageResponse) = try await URLSession.shared.data(for: imageRequest)
            guard let imageHTTP = imageResponse as? HTTPURLResponse,
                  (200...299).contains(imageHTTP.statusCode),
                  data.count <= 30_000_000,
                  imageHTTP.mimeType?.lowercased().hasPrefix("image/") == true,
                  NSImage(data: data) != nil else {
                throw ProviderError.invalidImageResponse
            }
            return data
        }
        throw ProviderError.invalidImageResponse
    }

    private static func generateGeminiImage(
        provider: ProviderConfiguration,
        apiKey: String,
        modelID: String,
        prompt: String,
        size: String,
        sourceImageURL: URL?
    ) async throws -> Data {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProviderError.missingAPIKey
        }
        var modelName = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        if modelName.hasPrefix("models/") { modelName.removeFirst("models/".count) }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        guard let encodedModel = modelName.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = endpoint(baseURL: provider.baseURL, suffix: "/models/\(encodedModel):generateContent") else {
            throw ProviderError.invalidURL(provider.baseURL)
        }

        var parts: [[String: Any]] = [["text": prompt]]
        if let sourceImageURL {
            let imageData = try Data(contentsOf: sourceImageURL)
            guard !imageData.isEmpty, imageData.count <= 20_000_000 else {
                throw ProviderError.imageInputTooLarge
            }
            let ext = sourceImageURL.pathExtension.lowercased()
            let mimeType = ext == "jpg" || ext == "jpeg" ? "image/jpeg"
                : ext == "webp" ? "image/webp"
                : ext == "heic" ? "image/heic"
                : "image/png"
            parts.insert([
                "inlineData": [
                    "mimeType": mimeType,
                    "data": imageData.base64EncodedString()
                ]
            ], at: 0)
        }
        let aspectRatio = size == "1536x1024" ? "3:2" : size == "1024x1536" ? "2:3" : "1:1"
        let body: [String: Any] = [
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": [
                "responseModalities": ["TEXT", "IMAGE"],
                "imageConfig": ["aspectRatio": aspectRatio]
            ]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 240
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.httpStatus(http.statusCode, Self.errorDetail(from: data))
        }
        let decoded = try JSONDecoder().decode(GeminiCompletionResponse.self, from: data)
        for part in decoded.candidates?.flatMap({ $0.content?.parts ?? [] }) ?? [] {
            guard let encoded = part.inlineData?.data,
                  let imageData = Data(base64Encoded: encoded),
                  !imageData.isEmpty else { continue }
            guard imageData.count <= 30_000_000 else { throw ProviderError.imageOutputTooLarge }
            guard NSImage(data: imageData) != nil else { continue }
            return imageData
        }
        throw ProviderError.invalidImageResponse
    }

    private struct GeminiCompletionResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable {
                    struct InlineData: Decodable {
                        let mimeType: String?
                        let data: String?
                    }
                    let text: String?
                    let inlineData: InlineData?
                }
                let parts: [Part]?
            }
            let content: Content?
        }
        let candidates: [Candidate]?
    }

    private struct GeminiModelList: Decodable {
        struct Item: Decodable {
            let name: String
            let supportedGenerationMethods: [String]?
        }
        let models: [Item]?
    }

    static func complete(
        provider: ProviderConfiguration,
        apiKey: String,
        messages: [ChatMessage],
        temperature: Double = 0.7,
        topP: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> String {
        guard !provider.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProviderError.missingModel
        }
        if provider.id == "gemini" {
            return try await completeGemini(
                provider: provider, apiKey: apiKey, messages: messages,
                temperature: temperature, topP: topP, maxTokens: maxTokens
            )
        }
        guard let url = endpoint(baseURL: provider.baseURL, suffix: "/chat/completions") else {
            throw ProviderError.invalidURL(provider.baseURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        if provider.id == "openrouter" { request.setValue("Supru App Builder", forHTTPHeaderField: "X-Title") }
        var body: [String: Any] = [
            "model": provider.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": false,
            "temperature": max(0, min(2, temperature))
        ]
        if let topP { body["top_p"] = max(0, min(1, topP)) }
        if let maxTokens { body["max_tokens"] = max(1, min(32768, maxTokens)) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.httpStatus(http.statusCode, Self.errorDetail(from: data))
        }
        let decoded = try JSONDecoder().decode(CompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw ProviderError.emptyResponse
        }
        return content
    }

    private static func completeGemini(
        provider: ProviderConfiguration,
        apiKey: String,
        messages: [ChatMessage],
        temperature: Double,
        topP: Double?,
        maxTokens: Int?
    ) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProviderError.missingAPIKey
        }
        var modelName = provider.model.trimmingCharacters(in: .whitespacesAndNewlines)
        if modelName.hasPrefix("models/") { modelName.removeFirst("models/".count) }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        guard let encodedModel = modelName.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = endpoint(baseURL: provider.baseURL, suffix: "/models/\(encodedModel):generateContent") else {
            throw ProviderError.invalidURL(provider.baseURL)
        }

        let systemText = messages.filter { $0.role == "system" }.map(\.content).joined(separator: "\n\n")
        let contents: [[String: Any]] = messages
            .filter { $0.role != "system" }
            .map { message in
                [
                    "role": message.role == "assistant" ? "model" : "user",
                    "parts": [["text": message.content]]
                ]
            }
        guard !contents.isEmpty else { throw ProviderError.emptyResponse }
        var generation: [String: Any] = ["temperature": max(0, min(2, temperature))]
        if let topP { generation["topP"] = max(0.05, min(1, topP)) }
        if let maxTokens { generation["maxOutputTokens"] = max(1, min(32768, maxTokens)) }
        var body: [String: Any] = ["contents": contents, "generationConfig": generation]
        if !systemText.isEmpty { body["systemInstruction"] = ["parts": [["text": systemText]]] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.httpStatus(http.statusCode, Self.errorDetail(from: data))
        }
        let decoded = try JSONDecoder().decode(GeminiCompletionResponse.self, from: data)
        let text = decoded.candidates?
            .flatMap { $0.content?.parts ?? [] }
            .compactMap(\.text)
            .joined(separator: "")
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProviderError.emptyResponse
        }
        return text
    }

    static func listModels(provider: ProviderConfiguration, apiKey: String) async throws -> [String] {
        guard let url = endpoint(baseURL: provider.baseURL, suffix: "/models") else {
            throw ProviderError.invalidURL(provider.baseURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 45
        if provider.id == "gemini" {
            guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ProviderError.missingAPIKey
            }
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        } else if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.httpStatus(http.statusCode, Self.errorDetail(from: data))
        }
        if provider.id == "gemini" {
            let decoded = try JSONDecoder().decode(GeminiModelList.self, from: data)
            return (decoded.models ?? [])
                .filter { $0.supportedGenerationMethods?.contains("generateContent") ?? true }
                .map { $0.name.hasPrefix("models/") ? String($0.name.dropFirst("models/".count)) : $0.name }
                .sorted()
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
    case missingAPIKey
    case invalidResponse
    case emptyResponse
    case invalidImageResponse
    case imageInputTooLarge
    case imageOutputTooLarge
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value): return "Invalid provider URL: \(value)"
        case .missingModel: return "Choose a model ID in Providers & Settings first."
        case .missingAPIKey: return "Enter and save an API key for Google Gemini in Providers & Settings."
        case .invalidResponse: return "The provider returned an invalid HTTP response."
        case .emptyResponse: return "The provider response did not contain assistant text."
        case .invalidImageResponse: return "The provider response did not contain a supported image. This endpoint must return data[].b64_json or a secure HTTPS image URL."
        case .imageInputTooLarge: return "The input image is empty or larger than 20 MB."
        case .imageOutputTooLarge: return "The returned image is larger than the 30 MB safety limit."
        case .httpStatus(let status, let detail): return "Provider returned HTTP \(status): \(detail)"
        }
    }
}
