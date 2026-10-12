# AI Studio Desktop — clean rebuild

This branch is a new desktop app implemented independently of the previous web application. The original Ref-01.jpeg, Ref-02.jpeg, and Ref-03.jpeg are preserved byte-for-byte as design references.

Requires Node.js 22+, Rust, and Tauri 2 platform prerequisites.

```sh
npm install
npm run tauri dev
```

Build a macOS DMG with `npm run tauri build`.

First milestone: fresh desktop workspace UI, Rust-side OpenAI-compatible chat-completions integration, sandboxed HTML preview, single-file HTML export, selectable accent color and temperature. Multi-file project export, provider-specific APIs, durable secure key storage, and desktop end-to-end verification are not yet implemented or verified.
