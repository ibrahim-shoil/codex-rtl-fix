$ErrorActionPreference = "Stop"

$nodeExe = Get-ChildItem `
    -Path (Join-Path $env:LOCALAPPDATA "OpenAI\Codex\bin\*\node.exe") `
    -File `
    -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 -ExpandProperty FullName

if (-not $nodeExe) {
    throw "Codex's local Node.js runtime was not found."
}

$syntaxFiles = @(
    "cdp-client.mjs",
    "rtl-payload.mjs",
    "rtl-injector.mjs",
    "rtl-apply-once.mjs",
    "rtl-diagnose.mjs"
)

foreach ($file in $syntaxFiles) {
    $process = Start-Process `
        -FilePath $nodeExe `
        -ArgumentList @("--check", (Join-Path $PSScriptRoot $file)) `
        -NoNewWindow `
        -Wait `
        -PassThru
    if ($process.ExitCode -ne 0) {
        throw "JavaScript syntax check failed: $file"
    }
}

$process = Start-Process `
    -FilePath $nodeExe `
    -ArgumentList @((Join-Path $PSScriptRoot "test-rtl-payload.mjs")) `
    -NoNewWindow `
    -Wait `
    -PassThru
if ($process.ExitCode -ne 0) {
    throw "RTL payload tests failed."
}

Write-Output "All Codex RTL checks passed."
