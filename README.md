# Codex RTL Fix

This local launcher improves mixed Arabic/English message rendering in the
Codex Windows app without modifying the signed Microsoft Store package.

It applies `dir="auto"` to rendered conversation text and keeps code-like
surfaces left-to-right. The prompt composer is intentionally left mostly
unchanged because changing Codex's ProseMirror editor DOM can break sending.

## Install

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Codex-RTL.ps1
```

Then:

1. Open **Codex RTL** from the Desktop or Start menu.
2. If Codex is already running, approve the relaunch prompt.
3. Use **Codex RTL** for future launches.
4. If a bad launch happens, run **Stop Codex RTL**, then open **Codex RTL**
   again.

The launcher resolves the currently installed Codex package every time, so it
does not depend on a specific app version. It does not alter `app.asar`.

## Mixed-direction test

Send these messages one by one:

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

Arabic prose should flow right-to-left. Paths, commands, URLs, and code should
remain left-to-right.

## Validate

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Test-Codex-RTL.ps1
```

## Limitation

The fix is active when Codex is opened using the **Codex RTL** shortcut. If an
app update changes Chromium debugging behavior or the conversation DOM
structure, the injector may need a small selector adjustment.

Prompt composer support is intentionally conservative. A direct ProseMirror
patch was tested and removed because it could make Codex unable to send
messages.
