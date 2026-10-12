import path from "node:path";

/**
 * Resolve the SQLite database file used by AIStudio.
 * Desktop launchers set AI_STUDIO_DATA_DIR to a writable OS app-data directory.
 * Development keeps the historical project-local ./data location.
 */
export function resolveDatabasePath(
  dataDirectory = process.env.AI_STUDIO_DATA_DIR,
  workingDirectory = process.cwd(),
): string {
  const directory = dataDirectory
    ? path.resolve(dataDirectory)
    : path.join(workingDirectory, "data");
  return path.join(directory, "ai-studio.db");
}
