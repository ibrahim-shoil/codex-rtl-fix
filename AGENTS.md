# Codex RTL Fix Agent Instructions

This repository ships a local launcher for the Codex Windows app. It improves
rendered mixed RTL/LTR message text without editing the signed Codex app
package.

Before changing behavior:

1. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\Test-Codex-RTL.ps1`.
2. Do not patch `app.asar` or files under `C:\Program Files\WindowsApps`.
3. Keep prompt-composer changes conservative. Patching Codex's ProseMirror
   editor previously broke message sending.
4. Do not commit `node_modules`, logs, temporary profiles, or local credentials.
5. Read `docs/CODEX_APP_AGENT_USAGE.md` before guiding a user through install,
   restart, live validation, or troubleshooting.

The project is for all right-to-left scripts, not Arabic only. Examples include
Arabic, Hebrew, Persian/Farsi, Urdu, Pashto, and Sindhi mixed with English,
paths, commands, URLs, or code.
