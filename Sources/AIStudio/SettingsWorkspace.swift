import SwiftUI

struct SettingsWorkspace: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Providers & Settings").font(.largeTitle).fontWeight(.bold)
                    Text("Connect local models or any OpenAI-compatible API. Provider URLs, model IDs, and conversation history are stored locally.")
                        .foregroundStyle(.secondary)
                }

                GroupBox("AI Provider") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Picker("Provider", selection: $model.selectedProviderID) {
                                ForEach(model.providers) { provider in
                                    Text(provider.name).tag(provider.id)
                                }
                            }
                            .onChange(of: model.selectedProviderID) { _ in model.selectProvider() }
                            Button { model.addOpenAICompatibleProvider() } label: {
                                Label("Add Custom", systemImage: "plus")
                            }
                        }

                        TextField("Provider display name", text: $model.providerName)
                            .textFieldStyle(.roundedBorder)
                        TextField("Base URL", text: $model.providerBaseURL)
                            .textFieldStyle(.roundedBorder)
                        TextField("Model ID", text: $model.providerModel)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            SecureField("API key (blank keeps the saved key)", text: $model.apiKeyDraft)
                            if model.selectedProviderHasKey {
                                Label("Key stored", systemImage: "checkmark.shield")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Button { model.saveProviderSettings() } label: {
                                Label("Save Provider", systemImage: "checkmark")
                            }
                            Button { model.fetchModels() } label: {
                                if model.isFetchingModels {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Label("Fetch Models", systemImage: "arrow.down.circle")
                                }
                            }
                            .disabled(model.isFetchingModels)
                            if model.selectedProviderHasKey {
                                Button("Remove Stored Key", role: .destructive) {
                                    model.removeStoredAPIKey()
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }

                if model.selectedProviderID == "ollama" {
                    Text("Ollama runs supported models locally on your Mac. No remote API key is required, but you must already have the model installed.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if !model.discoveredModels.isEmpty {
                    GroupBox("Model IDs returned by this endpoint") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select an ID to use it. Whether a model is free, and its usage limits, are determined by the provider—not by AIStudio.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            if model.selectedProviderID == "openrouter" {
                                Toggle("Only show model IDs ending in :free", isOn: $model.showOnlyFreeModels)
                            }
                            if model.showOnlyFreeModels && model.visibleDiscoveredModels.isEmpty {
                                Text("No :free model IDs were returned. Check the provider's current catalog and account access.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(model.visibleDiscoveredModels, id: \.self) { modelID in
                                Button { model.useDiscoveredModel(modelID) } label: {
                                    HStack {
                                        Text(modelID).textSelection(.enabled)
                                        Spacer()
                                        if modelID == model.providerModel {
                                            Image(systemName: "checkmark").foregroundStyle(.tint)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                GroupBox("Local data & project workspace") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("No sign-in or password gate.", systemImage: "lock.open")
                        Label("API keys are stored in macOS Keychain; they are not written into the settings JSON.", systemImage: "key.horizontal")
                        Label("Chat history and provider settings are saved in Application Support/AIStudio/state.json.", systemImage: "externaldrive")
                        HStack {
                            Text(model.workspaceURL?.path ?? "No project folder selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            Spacer()
                            Button("Open Folder…") { model.openWorkspace() }
                        }
                    }
                    .padding(.vertical, 6)
                }

                if let error = model.lastError {
                    Text(error).foregroundStyle(.red).textSelection(.enabled)
                }
                if let status = model.statusMessage {
                    Text(status).foregroundStyle(.secondary)
                }
                Text("This app does not include a web server. The Visual Editor uses WebKit only to preview files belonging to the project you open; the application interface is native macOS SwiftUI.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
