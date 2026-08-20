$ErrorActionPreference = "Stop"

$package = Get-AppxPackage -Name "OpenAI.Codex"
if (-not $package) {
    throw "The Codex Windows app is not installed."
}

$launcher = Join-Path $PSScriptRoot "Start-Codex-RTL.ps1"
if (-not (Test-Path -LiteralPath $launcher)) {
    throw "Launcher not found: $launcher"
}
$stopper = Join-Path $PSScriptRoot "Stop-Codex-RTL.ps1"
if (-not (Test-Path -LiteralPath $stopper)) {
    throw "Stopper not found: $stopper"
}
$diagnoser = Join-Path $PSScriptRoot "Diagnose-Codex-RTL.ps1"
if (-not (Test-Path -LiteralPath $diagnoser)) {
    throw "Diagnoser not found: $diagnoser"
}

$desktop = [Environment]::GetFolderPath("Desktop")
$startMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
$powershell = Join-Path $PSHOME "powershell.exe"
$icon = Join-Path $package.InstallLocation "app\ChatGPT.exe"
$shell = New-Object -ComObject WScript.Shell

foreach ($shortcutSpec in @(
    @{ Name = "Codex RTL.lnk"; Script = $launcher; Description = "Start Codex with automatic Arabic and English bidirectional text" },
    @{ Name = "Stop Codex RTL.lnk"; Script = $stopper; Description = "Stop Codex and the RTL injector" },
    @{ Name = "Diagnose Codex RTL.lnk"; Script = $diagnoser; Description = "Print Codex RTL process and log diagnostics" }
)) {
    foreach ($directory in @($desktop, $startMenu)) {
    $shortcutPath = Join-Path $directory $shortcutSpec.Name
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $powershell
    $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($shortcutSpec.Script)`""
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.IconLocation = "$icon,0"
    $shortcut.Description = $shortcutSpec.Description
    $shortcut.Save()
    }
}

Write-Output "Installed Codex RTL, Stop Codex RTL, and Diagnose Codex RTL shortcuts on the Desktop and in the Start menu."
