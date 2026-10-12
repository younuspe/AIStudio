# Supru App Builder

A native macOS desktop app for building small web apps from prompts, inspecting a live preview, editing source, and exporting project files. The desktop implementation lives in the `fresh-desktop/` directory. This branch is for the native desktop app, not the older web application.

> **Development status:** Work in progress. A successful build and a fresh install/launch test are still required before calling this release ready.

## Reference designs

The interface is guided by these project reference images:

- [Reference 01](Ref-01.jpeg)
- [Reference 02](Ref-02.jpeg)
- [Reference 03](Ref-03.jpeg)

Supru App Builder uses the project's own Supru cat artwork and branding, not Google's official logo.

## Current implementation

The current desktop workspace includes:

- Prompt input with Build, Ask, and Plan modes
- Live app preview and source-code editor
- Project-file list and visual element editing
- OpenAI-compatible chat-completions endpoints
- Ollama-compatible local endpoints
- Local session/settings storage and ZIP export of project files

This is a developing app, not a claim of full Google AI Studio feature parity or production readiness. Provider connections, project persistence, preview isolation, exported archives, and the packaged app require end-to-end testing.

## Build on macOS

Requirements: Node.js 22 LTS, Rust stable, and the macOS Xcode Command Line Tools.

```sh
cd fresh-desktop
npm install
npm run build
```

The GitHub Actions workflow is `.github/workflows/fresh-desktop-macos.yml`. It builds the macOS app and packages a DMG. The workflow uses free ad-hoc signing only; this is not Apple Developer ID signing or notarization, so macOS may still display a security warning.

## Project layout

```
fresh-desktop/
  ui/             # Desktop frontend and Supru artwork
  src-tauri/      # Tauri/Rust desktop shell and bundle configuration
  package.json    # Desktop build scripts
  README.md       # Desktop-specific setup and status
.github/
  workflows/
    fresh-desktop-macos.yml
Ref-01.jpeg
Ref-02.jpeg
Ref-03.jpeg
```

The older web application's files may still exist elsewhere in this repository. The native desktop app is implemented in `fresh-desktop/` and should not depend on the older web app's runtime.

## Free distribution

The project uses free build tooling and GitHub Actions. No paid signing certificate or paid notarization service is required for development builds. Without Apple Developer ID signing and notarization, Gatekeeper warnings may still occur.

## Security note

Do not commit API keys, tokens, or personal credentials. API-key storage and provider requests must be reviewed before production use.

## License

See [LICENSE.md](LICENSE.md).
