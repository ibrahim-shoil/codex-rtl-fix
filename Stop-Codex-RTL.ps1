$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
$debugLogPath = Join-Path $PSScriptRoot "rtl-stop-debug.log"

function Reset-DebugLog {
    Set-Content -LiteralPath $debugLogPath -Value "" -Encoding UTF8
}

function Write-DebugLog {
    param([string]$Message)
    $line = "{0} {1}" -f (Get-Date).ToString("o"), $Message
    Add-Content -LiteralPath $debugLogPath -Value $line -Encoding UTF8
}

try {
    Reset-DebugLog
    Write-DebugLog "stopper: start script=$PSCommandPath cwd=$PWD"
    $processes = Get-CimInstance Win32_Process |
        Where-Object { $_.Name -eq "ChatGPT.exe" -or ($_.Name -eq "node.exe" -and $_.CommandLine -like "*rtl-injector.mjs*") }
    foreach ($process in $processes) {
        Write-DebugLog "stopper: found pid=$($process.ProcessId) ppid=$($process.ParentProcessId) name=$($process.Name) cmd=$($process.CommandLine)"
    }

    $processes |
        Where-Object { $_.Name -eq "ChatGPT.exe" -and $_.CommandLine -notlike "* --type=*" } |
        ForEach-Object {
            try {
                Write-DebugLog "stopper: taskkill tree pid=$($_.ProcessId)"
                $output = & taskkill.exe /PID $_.ProcessId /T /F 2>&1
                $exitCode = $LASTEXITCODE
                Write-DebugLog "stopper: taskkill exit=$exitCode output=$($output -join ' | ')"
            } catch {
                Write-DebugLog "stopper: taskkill exception pid=$($_.ProcessId) message=$($_.Exception.Message)"
            }
        }

    $processes |
        Where-Object { $_.Name -eq "node.exe" -and $_.CommandLine -like "*rtl-injector.mjs*" } |
        ForEach-Object {
            try {
                Write-DebugLog "stopper: stop injector pid=$($_.ProcessId)"
                Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop
                Write-DebugLog "stopper: injector stopped pid=$($_.ProcessId)"
            } catch {
                Write-DebugLog "stopper: injector stop failed pid=$($_.ProcessId) message=$($_.Exception.Message)"
            }
        }

    Write-DebugLog "stopper: complete"

    [System.Windows.Forms.MessageBox]::Show(
        "Codex and the RTL injector were stopped. You can now open normal Codex or Codex RTL again.",
        "Codex RTL Fix",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
} catch {
    Write-DebugLog "stopper: fatal message=$($_.Exception.Message)"
    [System.Windows.Forms.MessageBox]::Show(
        $_.Exception.Message,
        "Codex RTL Fix",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}
