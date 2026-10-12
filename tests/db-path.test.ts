import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { resolveDatabasePath } from "../src/lib/db-path.ts";

test("uses the desktop app-data directory when configured", () => {
  assert.equal(
    resolveDatabasePath("/tmp/aistudio-data", "/workspace"),
    path.join("/tmp/aistudio-data", "ai-studio.db"),
  );
});

test("resolves relative app-data directories to absolute paths", () => {
  assert.equal(
    resolveDatabasePath("./Library/Application Support/AIStudio", "/workspace"),
    path.join("/workspace/Library/Application Support/AIStudio", "ai-studio.db"),
  );
});

test("keeps project-local data directory as the development fallback", () => {
  assert.equal(
    resolveDatabasePath(undefined, "/workspace"),
    path.join("/workspace", "data", "ai-studio.db"),
  );
});
