$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms

$processes = Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -eq "ChatGPT.exe" -or
        ($_.Name -eq "node.exe" -and $_.CommandLine -like "*rtl-injector.mjs*")
    } |
    Select-Object ProcessId,ParentProcessId,Name,CommandLine

$debugFiles = @(
    "rtl-launcher-debug.log",
    "rtl-stop-debug.log",
    "rtl-injector.log",
    "rtl-injector.err.log"
) | ForEach-Object {
    $path = Join-Path $PSScriptRoot $_
    [pscustomobject]@{
        Path = $path
        Exists = Test-Path -LiteralPath $path
        Content = if (Test-Path -LiteralPath $path) {
            [string]::Join("", [string[]](Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue))
        } else {
            $null
        }
    }
}

$summary = [pscustomobject]@{
    Time = (Get-Date).ToString("o")
    Processes = $processes
    DebugFiles = $debugFiles
}

$outputPath = Join-Path $PSScriptRoot "rtl-diagnose-summary.json"
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outputPath -Encoding UTF8
$summary | ConvertTo-Json -Depth 6 | Write-Output

[System.Windows.Forms.MessageBox]::Show(
    "Codex RTL diagnostics were written to:`n$outputPath",
    "Codex RTL Fix",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
) | Out-Null
