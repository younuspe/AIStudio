# Desktop Architecture Audit (2026-10-12)

## Verified repository facts
- Source branch audited: `public`; rebuild work belongs on `rebuild/desktop-from-scratch`.
- The three approved root-level references are exactly `Ref-01.jpeg`, `Ref-02.jpeg`, and `Ref-03.jpeg`. Keep their bytes unchanged.
- Existing application is `AIStudio` v1.7.2, built with Next.js 16.3.1, React 18, TypeScript, and Tailwind.
- The current app is not a static-only frontend. It has 15 API route groups under `src/app/api`, including chat, models, settings, API configs, conversations, messages, database diagnostics, TTS, password, templates, docs, and usage stats.
- The chat route imports the API adapter, local persistence, context/RAG logic, and unlock checks. `src/lib/db.ts` initializes a SQLite-compatible database at `process.cwd()/data/ai-studio.db`; it stores settings including API key, conversations, messages, blocks, API configs, model definitions, and embeddings.
- Existing API adapter contains both OpenAI-compatible and Gemini/Interactions request handling. This is useful implementation to preserve rather than replace with mock behavior.
- Current `next.config.js` has serverExternalPackages for native/runtime dependencies including `msedge-tts`, Hugging Face Transformers, ONNX Runtime, and Sharp.

## Architecture decision
Do **not** convert the existing Next app to a static export as a shortcut. Official Tauri guidance says its webview serves static frontend assets and does not natively run server-based Next.js functionality; Next static export does not support dynamic POST handlers, middleware, or runtime database writes. References:
- https://v2.tauri.app/start/frontend/nextjs/
- https://nextjs.org/docs/app/guides/backend-for-frontend

Preferred first desktop architecture: a native Tauri window plus a bundled, app-managed local Node/Next runtime (sidecar) on loopback, retaining the existing API routes and provider logic while the migration to Rust can be assessed feature by feature. The user must never manually launch a server or browser. The sidecar must bind only to loopback, use an app-owned writable data directory rather than the installation directory, report startup failures in the UI, and shut down with the desktop app. Do not ship this architecture until its runtime, dependency, licensing, startup, and security behavior are verified on macOS.

## Security and migration requirements
1. Move persistent data from `process.cwd()/data` to an app-data directory selected by the desktop host; add a safe migration for existing DB files.
2. Do not log prompts, attachment payloads, API keys, or sensitive provider settings. Review existing verbose chat-route logs before release.
3. Keep API keys out of renderer storage and source control. Use macOS Keychain where practical; otherwise document and encrypt the fallback.
4. Require loopback-only binding and a per-launch secret or equivalent request authorization for local API calls. Never expose the bundled service to the LAN.
5. Keep tool/code execution disabled unless implemented behind explicit user permission.
6. Preserve the existing three reference files byte-for-byte and implement UI changes against them.
7. Do not remove legacy features until their replacements have test coverage and are verified.

## Next audit tasks
- [ ] Enumerate all API route handlers and identify runtime-only dependencies.
- [ ] Audit lock/password flow, key persistence, DB migration, TTS, RAG/embeddings, and tool execution.
- [ ] Confirm native dependency/runtime packaging strategy for Apple Silicon macOS.
- [ ] Add a Tauri shell and launch/health-check/shutdown the backend from the app lifecycle.
- [ ] Add tests for sidecar authorization, loopback binding, database location/migration, and packaged startup.
- [ ] Implement and test UI against `Ref-01.jpeg`, `Ref-02.jpeg`, and `Ref-03.jpeg`.

## Status
This is a repository-based architecture audit, not a claim that the desktop app is already implemented or tested. No production build or installed-app test has been performed as part of this audit.
