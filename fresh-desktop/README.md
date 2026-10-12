# Supru App Builder — Native macOS App

Supru App Builder is a native macOS desktop-app implementation in `fresh-desktop/`. This branch keeps the desktop build separate from the older web application's runtime.

## Reference designs and branding

- [Reference 01](../Ref-01.jpeg)
- [Reference 02](../Ref-02.jpeg)
- [Reference 03](../Ref-03.jpeg)

The interface follows these references and uses the project's own Supru cat artwork, not Google's official logo.

## Current implementation scope

- Tauri 2 desktop shell and macOS app/DMG packaging.
- Workspace with prompt/chat, live preview, code editor, and project-file list.
- Build, Ask, and Plan interaction modes.
- OpenAI-compatible `/chat/completions` endpoint configuration.
- Ollama-compatible local endpoint option.
- Single-file HTML generation, source editing, live preview, visual element editing, and ZIP project export.

This is still a work in progress, not a claim of full Google AI Studio feature parity or production readiness. Provider calls, API-key storage, session persistence, preview isolation, ZIP exports, and the packaged application need end-to-end verification.

## Build on macOS

Requirements: Node.js 22 LTS, Rust stable, and the macOS Xcode Command Line Tools.

```sh
cd fresh-desktop
npm install
npm run build
```

The GitHub Actions workflow is `.github/workflows/fresh-desktop-macos.yml`. It builds the app and packages a DMG. It uses free ad-hoc signing only—not Apple Developer ID signing or notarization—so macOS may still show a security warning for downloaded builds.

## Project layout

```
fresh-desktop/
  ui/             # Desktop frontend and Supru artwork
  src-tauri/      # Tauri/Rust shell and bundle configuration
  package.json    # Desktop build scripts
.github/workflows/
  fresh-desktop-macos.yml
Ref-01.jpeg
Ref-02.jpeg
Ref-03.jpeg
```

## Security and limitations

- Do not commit API keys, tokens, or credentials.
- API-key storage and provider requests need a security review before production use.
- The macOS bundle must pass a real workflow build and install/launch test before it can be considered ready.

## License

See [LICENSE.md](../LICENSE.md)
