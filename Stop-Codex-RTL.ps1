$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms

try {
    $processes = Get-CimInstance Win32_Process |
        Where-Object { $_.Name -eq "ChatGPT.exe" -or ($_.Name -eq "node.exe" -and $_.CommandLine -like "*rtl-injector.mjs*") }

    $processes |
        Where-Object { $_.Name -eq "ChatGPT.exe" -and $_.CommandLine -notlike "* --type=*" } |
        ForEach-Object {
            try {
                & taskkill.exe /PID $_.ProcessId /T /F 2>$null | Out-Null
            } catch {}
        }

    $processes |
        Where-Object { $_.Name -eq "node.exe" -and $_.CommandLine -like "*rtl-injector.mjs*" } |
        ForEach-Object {
            try {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop
            } catch {}
        }

    [System.Windows.Forms.MessageBox]::Show(
        "Codex and the RTL injector were stopped. You can now open normal Codex or Codex RTL again.",
        "Codex RTL Fix",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        $_.Exception.Message,
        "Codex RTL Fix",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}
