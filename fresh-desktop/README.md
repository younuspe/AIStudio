# AI Studio Desktop — Fresh Rebuild

This is a new implementation placed in `fresh-desktop/`. It does not import or reuse the existing application's source files.

## Current scope
- Tauri 2 native desktop window and macOS app/DMG bundle configuration.
- Split workspace with prompt/chat, preview, code editor, and project-file list.
- OpenAI-compatible `/chat/completions` endpoint support, with endpoint and API key configuration.
- Ollama-compatible local endpoint option.
- Single-file HTML app generation, editable code, sandboxed live preview, and HTML export.
- Starter preview includes a working button interaction.

## Build prerequisites
Install Node.js LTS, Rust, and the macOS Xcode Command Line Tools. From this directory run:

```sh
npm install
npm run build
```

The macOS bundle has not been built or tested by this commit. Provider API keys are currently stored in browser local storage for this fresh prototype and should be moved to the OS keychain before production use. This is a new implementation foundation, not a claim of full Google AI Studio feature parity yet.
