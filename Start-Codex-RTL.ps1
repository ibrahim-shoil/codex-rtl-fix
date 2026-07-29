param(
    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms

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

try {
    $running = Get-Process -Name "ChatGPT" -ErrorAction SilentlyContinue
    if ($running -and -not $ValidateOnly) {
        if (-not (Confirm-RtlRestart)) {
            exit 1
        }
        $running | Stop-Process -Force
        Start-Sleep -Milliseconds 1500
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

    $logPath = Join-Path $PSScriptRoot "rtl-injector.log"
    $errPath = Join-Path $PSScriptRoot "rtl-injector.err.log"
    Set-Content -LiteralPath $logPath -Value "" -Encoding UTF8
    Set-Content -LiteralPath $errPath -Value "" -Encoding UTF8

    Start-Process `
        -FilePath $nodeExe `
        -ArgumentList @($injector, "--port", "$port") `
        -WorkingDirectory $PSScriptRoot `
        -WindowStyle Hidden

    $appArgs = @(
            "--remote-debugging-address=127.0.0.1",
            "--remote-debugging-port=$port",
            "--remote-allow-origins=http://127.0.0.1:$port"
        )

    Start-Process `
        -FilePath $appExe `
        -ArgumentList $appArgs
} catch {
    Show-RtlMessage `
        -Text $_.Exception.Message `
        -Icon ([System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}
