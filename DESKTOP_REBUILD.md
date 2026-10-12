# AIStudio Desktop Rebuild

## Objective

Build a real installable macOS desktop application inspired by Google Gemini AI Studio, using the three approved reference images as the UI source of truth. This is a functional application, not a static prototype.

## Safety rule

Work on `rebuild/desktop-from-scratch` only. Do not delete or rewrite the existing `public` branch. Preserve the three approved reference images exactly. Remove legacy implementation only from the rebuild branch after the replacement for each capability is implemented and verified.

## Architecture decision

The current repository is a Next.js application with server-side API/database functionality. Tauri's normal frontend asset mode does not run a Next.js server by itself. Do not set `output: "export"` blindly: first audit all server routes, database access, and provider handlers. Choose and document a desktop-safe architecture that keeps secrets out of the renderer and preserves working backend features. The shipped product must open as a native Tauri window and must not require the user to open a browser or manually start a server.

## Required product capabilities

- Match the three approved reference images as closely as practical; keep the references available in-repo.
- Real provider configuration: Gemini API and generic OpenAI-compatible endpoints (custom base URL, model listing where supported, API key stored securely, clear connection errors).
- Streaming and non-streaming generation, conversation history, model selection, system instructions, generation parameters, stop/regenerate, and usage/error display where supported by the provider.
- Attachments and multimodal inputs only where the selected provider supports them; explain unsupported formats rather than pretending they worked.
- Functional tools/settings only when backed by real implementations. Tool execution must be permission-gated and must never execute model-generated code silently.
- Persistent local data with migration/error handling, import/export, and safe handling of credentials.
- Real project workspace: create/open projects, read/write files, preview runnable apps, show build/runtime errors, and export a complete project folder. Do not label generated code as a working app until it builds/runs.
- Theme/color customization and responsive desktop layout.
- macOS Tauri app bundle/DMG with the approved icon if its source has suitable transparency and dimensions.

## Verification gates

1. Inventory all existing routes, provider adapters, database tables/migrations, tests, and the three exact reference images before removing legacy files.
2. Write an architecture decision for desktop backend/runtime and secure key storage.
3. Implement in small, reviewable commits on this branch.
4. Run typecheck/lint/unit tests and production build after each milestone; record exact commands and outcomes.
5. Test a real provider request using a user-supplied key without printing or committing the key. Test provider errors and missing-key behavior.
6. Test persistence across app restarts, attachments, conversation operations, and each implemented tool.
7. Build the macOS app and DMG on macOS; launch the packaged app and test core flows. A CI green check alone is not a substitute for opening and testing the installed app.
8. Only claim a capability works when its test evidence exists. Keep known limitations explicit.

## Milestones

- M0: Repository and reference inventory; identify existing useful logic and all destructive changes.
- M1: Desktop architecture and security boundary.
- M2: Tauri app shell, native menu/window, approved icon, local data.
- M3: Reference-matched UI and real provider/model configuration.
- M4: Streaming playground, conversations, generation settings, attachments.
- M5: Tools, persistence, import/export, and safety permissions.
- M6: Project workspace, live preview, build/run diagnostics, project export.
- M7: Automated tests, real-provider tests, macOS bundle/DMG verification.
- M8: Clean release artifacts and simple install instructions.

## Status

- [x] Dedicated rebuild branch created from `public`.
- [ ] Inventory the three approved image files by exact name and confirm which three are the authoritative references.
- [ ] Repository/server-route/database audit completed.
- [ ] Desktop architecture selected and implemented.
- [ ] Functional milestones verified.
- [ ] Packaged macOS app and DMG tested.

This file tracks intent only; it does not claim any implementation or test has completed.
