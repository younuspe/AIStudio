import AppKit
import SwiftUI

private enum GenerativeStudioMode: String, CaseIterable, Identifiable {
    case playground = "Model Playground"
    case images = "Image Studio"
    var id: String { rawValue }
}

private struct PlaygroundRun: Codable, Identifiable {
    var id = UUID()
    var providerName: String
    var modelID: String
    var systemInstruction: String
    var prompt: String
    var temperature: Double
    var topP: Double
    var maxTokens: Int
    var response: String
    var error: String?
    var createdAt = Date()
}

struct GenerativeStudioWorkspace: View {
    @ObservedObject var model: AppModel
    @State private var studioMode: GenerativeStudioMode = .playground
    @State private var modelIDs = ""
    @State private var systemInstruction = "You are a helpful, precise assistant. Follow the requested output format."
    @State private var playgroundPrompt = ""
    @State private var temperature = 0.7
    @State private var topP = 1.0
    @State private var maxTokens = 2048
    @State private var isRunningPlayground = false
    @State private var playgroundStatus = ""
    @State private var playgroundError: String?
    @State private var history: [PlaygroundRun] = []

    private let imageSizes = [
        "1024x1024",
        "1536x1024",
        "1024x1536"
    ]

    var body: some View {
        VStack(spacing: 0) {
            Picker("Generative Studio mode", selection: $studioMode) {
                ForEach(GenerativeStudioMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            Divider()
            Group {
                if studioMode == .playground {
                    modelPlayground
                } else {
                    imageStudio
                }
            }
        }
        .onAppear {
            if modelIDs.isEmpty { modelIDs = model.activeProvider.model }
            loadPlaygroundHistory()
        }
    }

    private var modelPlayground: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Model Playground").font(.largeTitle).fontWeight(.bold)
                    Text("Experiment with Google Gemini or your configured provider. Change system instructions and sampling parameters, compare up to three model IDs, and save or export actual responses.")
                        .foregroundStyle(.secondary)
                }
                GroupBox("Endpoint and model") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label(model.activeProvider.name, systemImage: model.activeProvider.isLocal ? "desktopcomputer" : "network")
                                .fontWeight(.medium)
                            Spacer()
                            Button("Provider Settings") { model.selectedSection = .settings }
                        }
                        Text(model.activeProvider.baseURL)
                            .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        TextField("Model ID (comma-separated, up to 3)", text: $modelIDs)
                            .textFieldStyle(.roundedBorder)
                        if !model.discoveredModels.isEmpty {
                            Menu("Insert available model") {
                                ForEach(model.discoveredModels, id: \.self) { id in
                                    Button(id) {
                                        if modelIDs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            modelIDs = id
                                        } else {
                                            modelIDs += ", \(id)"
                                        }
                                    }
                                }
                            }
                        } else {
                            Text("Use Providers & Settings to save a key and fetch the provider's current model list.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 5)
                }
                GroupBox("System instructions") {
                    TextEditor(text: $systemInstruction)
                        .frame(minHeight: 90)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.25)))
                        .padding(.vertical, 5)
                }
                GroupBox("Prompt") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextEditor(text: $playgroundPrompt)
                            .frame(minHeight: 140)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.25)))
                        HStack(spacing: 8) {
                            promptExample("Explain", prompt: "Explain this concept in clear steps, include a small example, and list any important caveats.")
                            promptExample("JSON output", prompt: "Return a JSON object with title, summary, assumptions, risks, and next_steps. Return only valid JSON.")
                            promptExample("Code review", prompt: "Review this proposed approach. Identify likely bugs, missing edge cases, and concrete tests. Separate facts from assumptions.")
                        }
                    }
                    .padding(.vertical, 5)
                }
                GroupBox("Generation parameters") {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack { Text("Temperature"); Spacer(); Text(String(format: "%.2f", temperature)).monospacedDigit().foregroundStyle(.secondary) }
                            Slider(value: $temperature, in: 0...2, step: 0.05)
                            Text("Lower values are more deterministic; higher values allow more variation.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            HStack { Text("Top-p"); Spacer(); Text(String(format: "%.2f", topP)).monospacedDigit().foregroundStyle(.secondary) }
                            Slider(value: $topP, in: 0.05...1, step: 0.05)
                        }
                        Stepper("Maximum output tokens: \(maxTokens)", value: $maxTokens, in: 128...16384, step: 128)
                    }
                    .padding(.vertical, 5)
                }
                HStack(spacing: 10) {
                    Button { runPlayground() } label: {
                        if isRunningPlayground {
                            ProgressView().controlSize(.small); Text("Running…")
                        } else {
                            Label("Run", systemImage: "play.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunningPlayground || playgroundPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || modelIDs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Export history…") { exportPlaygroundHistory() }.disabled(history.isEmpty)
                    Button("Clear history", role: .destructive) {
                        history.removeAll()
                        persistPlaygroundHistory()
                    }.disabled(history.isEmpty || isRunningPlayground)
                }
                if !playgroundStatus.isEmpty { Text(playgroundStatus).font(.callout).foregroundStyle(.secondary) }
                if let error = playgroundError { Text(error).foregroundStyle(.red).textSelection(.enabled) }
                HStack {
                    Text("Saved experiment results").font(.title2.weight(.semibold))
                    Spacer()
                    Text("\(history.count) run(s)").font(.caption).foregroundStyle(.secondary)
                }
                if history.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "testtube.2").font(.system(size: 32)).foregroundStyle(.secondary)
                        Text("No experiments yet").font(.headline)
                        Text("Run a prompt to see the real model response here. Results and errors are saved locally.")
                            .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(26)
                        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                } else {
                    ForEach(history) { run in
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(run.modelID).font(.headline).textSelection(.enabled)
                                        Text("\(run.providerName) · \(run.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("T \(String(format: "%.2f", run.temperature)) · p \(String(format: "%.2f", run.topP))")
                                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                }
                                Text(run.prompt).font(.callout).foregroundStyle(.secondary).lineLimit(3)
                                if let error = run.error {
                                    Text(error).foregroundStyle(.red).textSelection(.enabled)
                                } else {
                                    Text(run.response).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                }
                                HStack {
                                    Button("Load setup") {
                                        modelIDs = run.modelID
                                        systemInstruction = run.systemInstruction
                                        playgroundPrompt = run.prompt
                                        temperature = run.temperature
                                        topP = run.topP
                                        maxTokens = run.maxTokens
                                        studioMode = .playground
                                    }
                                    Button("Copy response") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(run.response, forType: .string)
                                        playgroundStatus = "Response copied."
                                    }.disabled(run.response.isEmpty)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func promptExample(_ title: String, prompt: String) -> some View {
        Button(title) { playgroundPrompt = prompt }
            .buttonStyle(.bordered)
    }

    private var playgroundHistoryURL: URL {
        AppModel.supportDirectory.appendingPathComponent("playground-history.json")
    }

    private func loadPlaygroundHistory() {
        do {
            let data = try Data(contentsOf: playgroundHistoryURL)
            history = try JSONDecoder().decode([PlaygroundRun].self, from: data)
        } catch {
            history = []
        }
    }

    private func persistPlaygroundHistory() {
        do {
            try FileManager.default.createDirectory(at: AppModel.supportDirectory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(history).write(to: playgroundHistoryURL, options: .atomic)
        } catch {
            playgroundError = "Could not save experiment history: \(error.localizedDescription)"
        }
    }

    private func runPlayground() {
        let ids = Array(modelIDs.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { values, id in
                if !values.contains(id) && values.count < 3 { values.append(id) }
            })
        guard !ids.isEmpty else { playgroundError = "Enter at least one model ID."; return }
        guard !playgroundPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            playgroundError = "Enter a prompt."; return
        }

        let configuredProvider = model.activeProvider
        let apiKey = KeychainStore.read(account: configuredProvider.keychainAccount) ?? ""
        let system = systemInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = playgroundPrompt
        let temperatureValue = temperature
        let topPValue = topP
        let maxTokensValue = maxTokens
        isRunningPlayground = true
        playgroundError = nil
        playgroundStatus = "Sending \(ids.count) real request(s) to \(configuredProvider.name)…"
        Task {
            var finished: [PlaygroundRun] = []
            for id in ids {
                var provider = configuredProvider
                provider.model = id
                var messages: [ChatMessage] = []
                if !system.isEmpty { messages.append(ChatMessage(role: "system", content: system)) }
                messages.append(ChatMessage(role: "user", content: prompt))
                do {
                    let response = try await AIProviderClient.complete(
                        provider: provider, apiKey: apiKey, messages: messages,
                        temperature: temperatureValue, topP: topPValue, maxTokens: maxTokensValue
                    )
                    finished.append(PlaygroundRun(
                        providerName: provider.name, modelID: id, systemInstruction: system,
                        prompt: prompt, temperature: temperatureValue, topP: topPValue,
                        maxTokens: maxTokensValue, response: response, error: nil
                    ))
                } catch {
                    finished.append(PlaygroundRun(
                        providerName: provider.name, modelID: id, systemInstruction: system,
                        prompt: prompt, temperature: temperatureValue, topP: topPValue,
                        maxTokens: maxTokensValue, response: "", error: error.localizedDescription
                    ))
                }
            }
            history = finished + history
            persistPlaygroundHistory()
            isRunningPlayground = false
            let succeeded = finished.filter { $0.error == nil }.count
            playgroundStatus = "\(succeeded) of \(finished.count) requests succeeded. Results and failures are saved."
        }
    }

    private func exportPlaygroundHistory() {
        let panel = NSSavePanel()
        panel.title = "Export model playground history"
        panel.nameFieldStringValue = "AIStudio-Playground-History.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(history).write(to: url, options: .atomic)
            playgroundStatus = "Exported history to \(url.path)"
            playgroundError = nil
        } catch {
            playgroundError = "Could not export history: \(error.localizedDescription)"
        }
    }

    private var imageStudio: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Generative Studio")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Create an image from a prompt or edit a local image. Results are generated by your selected provider and saved only when you choose a destination.")
                        .foregroundStyle(.secondary)
                }

                GroupBox("Model & Output") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: model.activeProvider.isLocal ? "desktopcomputer" : "network")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(model.activeProvider.name).fontWeight(.semibold)
                                Text(model.activeProvider.baseURL)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            Spacer()
                            Button("Provider Settings") { model.selectedSection = .settings }
                        }

                        TextField("Image model ID (for example, gpt-image-1)", text: $model.imageModelID)
                            .textFieldStyle(.roundedBorder)
                        Picker("Image size", selection: $model.imageSize) {
                            ForEach(imageSizes, id: \.self) { size in
                                Text(size).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("The chosen provider must implement the OpenAI-compatible /images/generations endpoint. Editing also requires /images/edits. These endpoints may be paid even when the provider offers free chat models.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                GroupBox("Prompt") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $model.imagePrompt)
                            .font(.body)
                            .frame(minHeight: 120)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                            .accessibilityLabel("Image generation prompt")
                        Text("Describe the subject, composition, visual style, lighting, and important details. When a source image is attached, describe what should change and what should remain unchanged.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                GroupBox("Optional source image") {
                    HStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.imageSourceURL?.lastPathComponent ?? "No source image selected")
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(model.imageSourceURL?.path ?? "Generate a new image, or choose a local image to request an edit.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .textSelection(.enabled)
                        }
                        Spacer()
                        Button {
                            model.chooseImageSource()
                        } label: {
                            Label("Choose Image…", systemImage: "folder")
                        }
                        if model.imageSourceURL != nil {
                            Button {
                                model.clearImageSource()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove the source image")
                        }
                    }
                    .padding(.vertical, 6)
                }

                HStack(spacing: 10) {
                    Button {
                        model.generateImage()
                    } label: {
                        if model.isGeneratingImage {
                            ProgressView().controlSize(.small)
                            Text("Generating…")
                        } else {
                            Label(model.imageSourceURL == nil ? "Generate Image" : "Generate Edit",
                                  systemImage: "sparkles")
                        }
                    }
                    .disabled(model.isGeneratingImage || model.imagePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.borderedProminent)

                    Button {
                        model.saveGeneratedImage()
                    } label: {
                        Label("Save PNG…", systemImage: "square.and.arrow.down")
                    }
                    .disabled(model.generatedImageData == nil)}

                if let error = model.lastError {
                    Text(error)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let status = model.statusMessage {
                    Text(status)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                GroupBox("Generated Result") {
                    if let data = model.generatedImageData, let image = NSImage(data: data) {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: 640)
                                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            Text("Review the result and choose Save PNG… to store it locally.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 34))
                                .foregroundStyle(.secondary)
                            Text("Your generated image will appear here")
                                .font(.headline)
                            Text("AIStudio does not show mock artwork as successful generation. If your provider does not support image requests, it will display the provider's error.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 520)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(30)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
