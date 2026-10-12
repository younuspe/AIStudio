# AI Studio Desktop

An independent desktop-app rebuild of the AI Studio-style workspace, developed in the `fresh-desktop/` directory. This branch is focused on a native macOS application—not the previous web application.

> **Development status:** Work in progress. The macOS build has not yet been verified successfully. Do not treat this branch as a production-ready release.

## Reference designs

The UI work is guided by these project reference images:

- [Reference 01](Ref-01.jpeg)
- [Reference 02](Ref-02.jpeg)
- [Reference 03](Ref-03.jpeg)

The app uses the project's own cat artwork and branding, not Google's official logo.

## Current implementation

The fresh desktop app currently provides a Tauri 2 desktop shell and a workspace foundation for:

- Chat/prompt input and a live preview area
- Code editing and a project-file list
- OpenAI-compatible chat-completions endpoints
- Ollama-compatible local endpoints
- Editing and exporting a generated single-file HTML app

These are current implementation goals/features, not a claim of full Google AI Studio feature parity. Provider calls, API-key persistence, preview isolation, and the packaged app still require end-to-end verification.

## Build on macOS

Requirements: Node.js 22 LTS, Rust stable, and the macOS Xcode Command Line Tools.

```sh
cd fresh-desktop
npm install
npm run build
```

The GitHub Actions workflow is `.github/workflows/fresh-desktop-macos.yml`. It builds the macOS app and packages a DMG. The workflow currently uses ad-hoc signing only; this is free and is **not** Apple Developer ID signing or notarization. macOS may still display a security warning when opening the downloaded app.

## Project layout

```
fresh-desktop/
  ui/             # Desktop frontend and app artwork
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

The older web application's files may still exist elsewhere in this repository while cleanup and separation are in progress. The new desktop app's implementation is contained in `fresh-desktop/`; it should not depend on the old web app's runtime.

## Free distribution

The project uses free build tooling and GitHub Actions. No paid signing certificate or paid notarization service is required for development builds. Without Apple Developer ID signing and notarization, Gatekeeper warnings may still occur.

## Security note

Do not commit API keys, tokens, or personal credentials. Before production use, API-key storage and provider requests must be reviewed and verified.

## License

See [LICENSE.md](LICENSE.md).
