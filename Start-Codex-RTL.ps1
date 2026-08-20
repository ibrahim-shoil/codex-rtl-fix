param(
    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
$debugLogPath = Join-Path $PSScriptRoot "rtl-launcher-debug.log"

function Reset-DebugLog {
    Set-Content -LiteralPath $debugLogPath -Value "" -Encoding UTF8
}

function Write-DebugLog {
    param([string]$Message)
    $line = "{0} {1}" -f (Get-Date).ToString("o"), $Message
    Add-Content -LiteralPath $debugLogPath -Value $line -Encoding UTF8
}

function Format-ProcessLine {
    param($Process)
    return "pid=$($Process.ProcessId) ppid=$($Process.ParentProcessId) name=$($Process.Name) cmd=$($Process.CommandLine)"
}

function Show-RtlMessage {
    param(
        [string]$Text,
        [string]$Title = "Codex RTL Fix",
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )
    [System.Windows.Forms.MessageBox]::Show(
        $Text,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        $Icon
    ) | Out-Null
}

function Confirm-RtlRestart {
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Codex is already running. To enable RTL, Codex must be relaunched from this shortcut. Close Codex and start Codex RTL now?",
        "Codex RTL Fix",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    return $result -eq [System.Windows.Forms.DialogResult]::Yes
}

function Stop-CodexProcesses {
    Write-DebugLog "stop: enumerate Codex processes"
    $processes = Get-CimInstance Win32_Process |
        Where-Object { $_.Name -eq "ChatGPT.exe" -or ($_.Name -eq "node.exe" -and $_.CommandLine -like "*rtl-injector.mjs*") }

    foreach ($process in $processes) {
        Write-DebugLog ("stop: found " + (Format-ProcessLine $process))
    }

    $roots = $processes |
        Where-Object { $_.Name -eq "ChatGPT.exe" -and $_.CommandLine -notlike "* --type=*" }

    foreach ($process in $roots) {
        try {
            Write-DebugLog "stop: taskkill tree pid=$($process.ProcessId)"
            $output = & taskkill.exe /PID $process.ProcessId /T /F 2>&1
            $exitCode = $LASTEXITCODE
            Write-DebugLog "stop: taskkill exit=$exitCode output=$($output -join ' | ')"
        } catch {
            Write-DebugLog "stop: taskkill exception pid=$($process.ProcessId) message=$($_.Exception.Message)"
        }
    }

    $processes |
        Where-Object { $_.Name -eq "node.exe" -and $_.CommandLine -like "*rtl-injector.mjs*" } |
        ForEach-Object {
            try {
                Write-DebugLog "stop: stop injector pid=$($_.ProcessId)"
                Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop
                Write-DebugLog "stop: injector stopped pid=$($_.ProcessId)"
            } catch {
                Write-DebugLog "stop: injector stop failed pid=$($_.ProcessId) message=$($_.Exception.Message)"
            }
        }
}

function Wait-CodexClosed {
    param([int]$TimeoutSeconds = 12)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $main = Get-CimInstance Win32_Process |
            Where-Object { $_.Name -eq "ChatGPT.exe" -and $_.CommandLine -notlike "* --type=*" }
        if (-not $main) {
            Write-DebugLog "wait-close: main Codex process is gone"
            return $true
        }
        foreach ($process in $main) {
            Write-DebugLog ("wait-close: still running " + (Format-ProcessLine $process))
        }
        Start-Sleep -Milliseconds 300
    } while ((Get-Date) -lt $deadline)

    Write-DebugLog "wait-close: timeout after $TimeoutSeconds seconds"
    return $false
}

function Start-CodexPackagedApp {
    param(
        [string]$PackageFamilyName,
        [string[]]$Arguments
    )

    $argString = $Arguments -join " "
    Write-DebugLog "launcher: packageLaunch packageFamilyName=$PackageFamilyName appId=App command=ChatGPT.exe args=$argString"
    Invoke-CommandInDesktopPackage `
        -PackageFamilyName $PackageFamilyName `
        -AppId "App" `
        -Command "ChatGPT.exe" `
        -Args $argString
}

try {
    Reset-DebugLog
    Write-DebugLog "launcher: start validateOnly=$ValidateOnly script=$PSCommandPath cwd=$PWD"
    $running = Get-Process -Name "ChatGPT" -ErrorAction SilentlyContinue
    Write-DebugLog "launcher: initial ChatGPT count=$(($running | Measure-Object).Count)"
    if ($running -and -not $ValidateOnly) {
        if (-not (Confirm-RtlRestart)) {
            Write-DebugLog "launcher: user declined relaunch"
            exit 1
        }
        Write-DebugLog "launcher: user approved relaunch"
        Stop-CodexProcesses
        if (-not (Wait-CodexClosed)) {
            Show-RtlMessage `
                -Text "Codex did not close completely. Quit Codex from the system tray, then open Codex RTL again." `
                -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning)
            exit 1
        }
    }

    $package = Get-AppxPackage -Name "OpenAI.Codex"
    if (-not $package) {
        throw "The Codex Windows app is not installed."
    }

    $appExe = Join-Path $package.InstallLocation "app\ChatGPT.exe"
    $injector = Join-Path $PSScriptRoot "rtl-injector.mjs"
    $nodeExe = Get-ChildItem `
        -Path (Join-Path $env:LOCALAPPDATA "OpenAI\Codex\bin\*\node.exe") `
        -File `
        -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName

    if (-not $nodeExe) {
        throw "Codex's local Node.js runtime was not found under $env:LOCALAPPDATA\OpenAI\Codex\bin."
    }

    Write-DebugLog "launcher: packageVersion=$($package.Version)"
    Write-DebugLog "launcher: packageFamilyName=$($package.PackageFamilyName)"
    Write-DebugLog "launcher: appExe=$appExe"
    Write-DebugLog "launcher: nodeExe=$nodeExe"
    Write-DebugLog "launcher: injector=$injector"

    foreach ($path in @($appExe, $nodeExe, $injector)) {
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Required file was not found: $path"
        }
    }

    if ($ValidateOnly) {
        [pscustomobject]@{
            PackageVersion = $package.Version
            AppExecutable = $appExe
            NodeExecutable = $nodeExe
            Injector = $injector
            DebugLog = $debugLogPath
        } | ConvertTo-Json -Compress | Write-Output
        exit 0
    }

    $listener = [System.Net.Sockets.TcpListener]::new(
        [System.Net.IPAddress]::Loopback,
        0
    )
    $listener.Start()
    $port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    $listener.Stop()
    Write-DebugLog "launcher: selectedPort=$port"

    $logPath = Join-Path $PSScriptRoot "rtl-injector.log"
    $errPath = Join-Path $PSScriptRoot "rtl-injector.err.log"
    Set-Content -LiteralPath $logPath -Value "" -Encoding UTF8
    Set-Content -LiteralPath $errPath -Value "" -Encoding UTF8
    Write-DebugLog "launcher: reset injector logs log=$logPath err=$errPath"

    $injectorProcess = Start-Process `
        -FilePath $nodeExe `
        -ArgumentList @($injector, "--port", "$port") `
        -WorkingDirectory $PSScriptRoot `
        -WindowStyle Hidden `
        -PassThru
    Write-DebugLog "launcher: injectorStarted pid=$($injectorProcess.Id)"

    $appArgs = @(
            "--remote-debugging-address=127.0.0.1",
            "--remote-debugging-port=$port",
            "--remote-allow-origins=http://127.0.0.1:$port"
        )

    Write-DebugLog "launcher: appArgs=$($appArgs -join ' ')"
    try {
        Start-CodexPackagedApp `
            -PackageFamilyName $package.PackageFamilyName `
            -Arguments $appArgs
        Write-DebugLog "launcher: appLaunchCommandCompleted"
    } catch {
        Write-DebugLog "launcher: appLaunchFailed message=$($_.Exception.Message)"
        try {
            Stop-Process -Id $injectorProcess.Id -Force -ErrorAction Stop
            Write-DebugLog "launcher: injectorStoppedAfterLaunchFailure pid=$($injectorProcess.Id)"
        } catch {
            Write-DebugLog "launcher: injectorStopAfterLaunchFailureFailed pid=$($injectorProcess.Id) message=$($_.Exception.Message)"
        }
        throw
    }
} catch {
    Write-DebugLog "launcher: fatal message=$($_.Exception.Message)"
    Show-RtlMessage `
        -Text $_.Exception.Message `
        -Icon ([System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}
