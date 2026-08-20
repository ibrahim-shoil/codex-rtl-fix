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

foreach ($script in @(
    "Start-Codex-RTL.ps1",
    "Stop-Codex-RTL.ps1",
    "Install-Codex-RTL.ps1",
    "Diagnose-Codex-RTL.ps1"
)) {
    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $PSScriptRoot $script),
        [ref]$tokens,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        throw "PowerShell syntax check failed: $script"
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
