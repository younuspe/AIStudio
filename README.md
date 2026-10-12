# Supru App Builder — Native macOS Desktop App

Supru App Builder is a standalone macOS application using SwiftUI and AppKit. Its own interface is native; it does not wrap a website, start Next.js, or require a browser.

## Current native foundation

- Native macOS window, sidebar, menus, and keyboard shortcuts.
- Chat with locally persisted conversation history, app-building prompt starters, and macOS voice dictation into the editable prompt.
- Local Ollama, native Google Gemini API, NVIDIA, OpenRouter, OpenAI, and generic OpenAI-compatible endpoints with configurable model IDs.
- Provider model catalog lookup and free-tier filtering for model IDs ending in :free when the provider reports those IDs.
- API keys stored in macOS Keychain, not in the application state JSON.
- Open a local project folder, browse files, create folders and files, rename/delete files, edit UTF-8 text, and save changes.
- Attach up to eight source/text files to a chat message, with per-file and total context limits.
- Create an app directly from Chat, select a destination folder, generate up to 60 source files, validate paths and duplicates, confirm overwrites, report the file list in the same conversation, reveal the full project in Finder, and preview from beside chat.
- Generative Studio with a model playground (system instructions, temperature, top-p, output-token limits, model comparisons, saved/exportable runs), Image Studio with OpenAI-compatible or native Gemini image generation/editing where supported, and local PNG export.
- Visual property controls that write CSS overrides into an HTML entry page, including Vite-style projects.
- Live preview of static HTML or a project dev server configured to listen on loopback.
- Developer console for commands the user explicitly enters and runs.
- No sign-in or password gate.

## Important limitations

This is the native desktop foundation, not a claim that every planned advanced editing feature is complete. The project editor is a text editor; full Photoshop/Figma-grade semantic editing, unrestricted cross-format document editing, and a full multi-agent orchestration engine are not yet implemented in this native rewrite.

Image generation/editing requires a model/provider that supports image output: OpenAI-compatible providers use /images/generations or /images/edits; Google Gemini uses its native generateContent endpoint. Not every text model supports image output, and free chat access does not imply free image generation. Voice dictation requires macOS microphone and speech-recognition permissions. Generated apps still require review, dependency installation, and build/test verification; file generation alone is not proof of functionality. Supru App Builder reports provider errors rather than simulated success.

## Build a standalone macOS app

Requirements: macOS 13 or later and the Swift toolchain/Xcode Command Line Tools.

From the repository root on a Mac:

    chmod +x scripts/build-macos-app.sh
    ./scripts/build-macos-app.sh
    open "dist/Supru App Builder.app"

The build script compiles arm64 and x86_64 Swift executables and combines them into a Universal 2 dist/Supru App Builder.app, so the same build supports Apple Silicon and Intel Macs. Supru App Builder's own UI does not require a Node.js development server. The build is locally ad-hoc signed and not Apple-notarized. The packaging script embeds the original Supru Stud `AppIcon.icns` from a pinned commit when no local `assets/AppIcon.icns` is present. The icon is bundled into the app; it is not fetched at runtime. On first launch, try Control-clicking the app in Finder and choosing Open. Because the app is not notarized, Gatekeeper may still block it; ad-hoc signing fixes bundle integrity but does not replace Apple Developer ID signing and notarization.

To choose another output location:

    ./scripts/build-macos-app.sh "$HOME/Applications/Supru App Builder.app"

## Provider setup

Open Providers & Settings inside the app.

- Ollama: the default endpoint is http://127.0.0.1:11434/v1. Select a model already installed locally.
- OpenRouter: the default endpoint is https://openrouter.ai/api/v1. Add your key and fetch its model list. Some model IDs may end in :free; availability and limits can change.
- NVIDIA: the default endpoint is https://integrate.api.nvidia.com/v1. Add your key and select a model available to your account.
- OpenAI-compatible: configure any service that implements /v1/chat/completions and /v1/models. Custom local and remote endpoints are supported.

A provider's pricing, free quota, model access, and endpoint compatibility are determined by that provider, not AIStudio.

## Local data

- Provider settings and chat history: ~/Library/Application Support/AIStudio/state.json
- API keys: macOS Keychain service com.aistudio.desktop.providers
- Project files: saved directly to the directory you select
- Preview server logs: ~/Library/Application Support/AIStudio/project-preview.log

Review generated code and shell commands before executing them. Chat attachments and project prompts may contain private material; remote providers receive the contents sent with your request.

## Workflow isolation and status

All current desktop work is on the separate branch named desktop-productization in the AIStudio repository. The GitHub Actions build is configured only for pushes to that branch or a manual dispatch. It does not run for pull requests, and no pull request is created automatically. Commits made to this branch update the fork's branch only; they do not update the parent repository's public branch.

The app is not release-ready until the branch's automated build, startup smoke test, and live provider/file-workspace tests pass.
