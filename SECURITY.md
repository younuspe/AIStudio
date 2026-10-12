# Security

- Provider API keys are stored in macOS Keychain, not in source files or the JSON settings store.
- Local conversations and non-secret provider configuration are stored under \`~/Library/Application Support/AIStudio/\`.
- The application uses direct \`URLSession\` calls to the configured provider; it does not launch a local web server.
- Project editing is limited to a directory selected by the user. Model-generated paths are checked against that directory and path traversal entries are rejected.
- Generated project output is limited to 120 files, 1 MB per file, and 20 MB total. Existing targets trigger a replacement confirmation.
- Model-generated code is untrusted. Inspect project files before building or executing them.
- A remote provider receives any prompt and project content included in a request.

Report security issues privately to the repository maintainer rather than publishing access tokens, API keys, or private project files.
