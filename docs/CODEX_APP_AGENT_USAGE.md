# Codex App Agent Usage Guide

Use this guide when a Codex agent needs to help a user install, test, debug, or
maintain this RTL/LTR rendering fix for the Codex Windows app.

## Scope

This project improves rendered conversation messages in the Codex Windows app
when right-to-left languages are mixed with left-to-right content.

It is not Arabic-only. It targets RTL scripts such as Arabic, Hebrew,
Persian/Farsi, Urdu, Pashto, Sindhi, and similar languages.

The launcher does not modify the signed Codex app package. It starts Codex with
a local Chromium DevTools port, runs a small injector, and applies `dir="auto"`
plus `unicode-bidi` rules to rendered message elements.

## Important Safety Notes

- Do not edit `app.asar`.
- Do not edit files under `C:\Program Files\WindowsApps`.
- Do not apply broad CSS to the whole app shell.
- Do not patch `[contenteditable]` globally.
- Do not patch Codex's `.ProseMirror` composer unless you are explicitly
  investigating the prompt-composer issue. A direct ProseMirror patch was tested
  and made Codex unable to send messages.
- Keep code blocks, inline code, terminals, and editor-like surfaces LTR.

## Install For A User

From this repository directory, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Codex-RTL.ps1
```

This creates two shortcuts on the Desktop and in the Start menu:

- `Codex RTL`
- `Stop Codex RTL`

Tell the user to launch Codex with `Codex RTL`, not the normal Codex shortcut.

## Normal Launch Workflow

1. Open `Codex RTL`.
2. If Codex is already running, approve the relaunch prompt.
3. Wait a few seconds after the app opens. The injector waits briefly before
   applying the payload so Codex can finish booting.
4. Test message rendering with mixed RTL/LTR examples.

If the app opens dark, hangs, or behaves incorrectly:

1. Run `Stop Codex RTL`.
2. Open `Codex RTL` again.
3. Inspect:
   - `rtl-injector.log`
   - `rtl-injector.err.log`

If Windows shows `Access is denied` while stopping or relaunching Codex, it is
usually a protected or already-exiting helper process. The stop/relaunch scripts
should treat process cleanup as best effort and continue when possible.

If `Codex RTL` opens the normal app without RTL, inspect the process command
line. A working launch has `--remote-debugging-port=<port>` on the main
`ChatGPT.exe` process. If the main process has no remote-debugging flags, Codex
did not close before relaunch and Electron reused the existing normal instance.
The launcher should stop the main Codex process tree first and wait until the
main process exits before starting the RTL instance.

## Validation

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Test-Codex-RTL.ps1
```

Expected output:

```text
RTL payload syntax and direction contracts passed.
All Codex RTL checks passed.
```

This is a static/local validation. It does not prove the live Codex renderer is
visually correct. For live validation, use the diagnostic script with the active
debugging port.

## Find The Active Debug Port

Use PowerShell:

```powershell
Get-CimInstance Win32_Process |
  Where-Object {
    ($_.Name -eq "ChatGPT.exe" -and $_.CommandLine -like "*remote-debugging-port*") -or
    ($_.Name -eq "node.exe" -and $_.CommandLine -like "*rtl-injector.mjs*")
  } |
  Select-Object ProcessId,ParentProcessId,Name,CommandLine
```

Look for `--remote-debugging-port=<port>`.

## Live DOM Diagnosis

After finding the port, run:

```powershell
node .\rtl-diagnose.mjs <port>
```

Expected signals:

- `rootFlag` is `"1"`
- `stylePresent` is `true`
- rendered RTL message paragraphs have `dir: "auto"`
- computed `direction` is `"rtl"` for RTL text
- code-like surfaces remain LTR

## Manual Test Messages

Send these one by one inside Codex:

```text
هذا نص عربي فقط لاختبار اتجاه الكتابة وعلامات الترقيم؟
```

```text
هذا اختبار mixed بين Arabic و English داخل نفس السطر.
```

```text
Version 1.2 يعمل مع النص العربي بشكل صحيح؟
```

```text
الكود يبقى LTR: npm install && node index.js
```

```text
בדיקה בעברית mixed with English and version 1.2
```

```text
این یک تست فارسی mixed with English است.
```

```text
یہ اردو test mixed with English ہے.
```

Pass criteria:

- Messages send normally.
- RTL prose is readable after sending.
- English words, version numbers, paths, URLs, commands, and code-like text stay
  readable left-to-right.

## Prompt Composer Limitation

The prompt composer may not look perfect while typing. That is intentional for
the current stable version.

The tested unsafe approach was adding `.ProseMirror` and `.ProseMirror p` to
the RTL payload. It made Codex unable to send messages, so it was removed.

If investigating prompt-composer RTL support:

1. Work on a separate branch.
2. Keep `Test-Codex-RTL.ps1` passing.
3. Verify that sending still works before claiming success.
4. Prefer narrow editor attributes or app-supported settings over broad CSS.
5. Add a recovery path before asking users to test.

Track that work in the GitHub issue:

```text
Investigate safe RTL support for prompt composer
```
