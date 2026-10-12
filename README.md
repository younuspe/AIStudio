# AIStudio — Native macOS Desktop App

AIStudio is being rebuilt as a standalone macOS application using **SwiftUI and AppKit**. Its own interface is native; it does not wrap a website, start Next.js, or require a browser.

## Current native foundation

- Native macOS app window, sidebar, menus, and keyboard shortcuts.
- Chat UI with conversation history persisted locally.
- Ollama local-model endpoint plus configurable NVIDIA, OpenRouter, and generic OpenAI-compatible endpoints.
- Model catalog fetch through OpenAI-compatible \`/models\` endpoints.
- API keys stored in macOS Keychain, not in the app's JSON state file.
- Project folder picker and local file browser.
- Create files and folders, edit UTF-8 text files, and save changes directly to disk.
- Model-driven project generation that writes returned files into the selected directory, with path traversal protections, size caps, and an overwrite confirmation.
- Local HTML preview for a project you open. WebKit is used only as the project preview; AIStudio's own UI remains native.
- No sign-in or password gate.

This is the first implementation milestone, not a claim that every planned editor capability is finished. It still needs an actual macOS build and live testing before it can be called release-ready.

## Requirements

- macOS 13 or later
- Xcode Command Line Tools (Swift toolchain)
- An AI provider, or a local Ollama installation and downloaded model, for AI features

## Build a standalone \`.app\`

From the repository root on a Mac:

\`\`\`bash
chmod +x scripts/build-macos-app.sh
./scripts/build-macos-app.sh
open dist/AIStudio.app
\`\`\`

The script compiles the Swift package and packages it as \`dist/AIStudio.app\`. The app does not need a Node.js development server. This unsigned build may require macOS to be told to open it, and it is not code-signed or notarized.

To choose another output location:

\`\`\`bash
./scripts/build-macos-app.sh "$HOME/Applications/AIStudio.app"
\`\`\`

## Providers

Open **Providers & Settings** inside the app:

- **Ollama:** base URL defaults to \`http://127.0.0.1:11434/v1\`. Choose a model already installed locally.
- **OpenRouter:** base URL defaults to \`https://openrouter.ai/api/v1\`. Add your key and fetch the catalog. Some provider listings may offer free-tier models; availability, rate limits, and pricing can change.
- **NVIDIA API:** base URL defaults to \`https://integrate.api.nvidia.com/v1\`. Add your key and choose a model supported by your account.
- **OpenAI-compatible:** configure any service exposing the compatible \`/v1/chat/completions\` and \`/v1/models\` endpoints. Custom local and remote endpoints are supported.

AIStudio does not promise every model is free. The provider determines which models the account can access and what limits apply.

## Local project data

- Provider settings and chat history: \`~/Library/Application Support/AIStudio/state.json\`
- API keys: macOS Keychain service \`com.aistudio.desktop.providers\`
- Project files: saved directly to the directory you select

## Important security notes

AIStudio sends prompts and included project instructions to the provider you select. Do not send confidential material to a remote provider unless its terms and privacy rules are acceptable. The project generator validates relative file paths and asks before replacing existing files; review generated code before running it.

## Development status

This branch replaces the web application entry point with a Swift package and app-bundle build script. It has not yet been compiled or run on a Mac in this environment. Do not treat the app as verified until the native build, provider live tests, project editing, and project generation have been tested on macOS.
