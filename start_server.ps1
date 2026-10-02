$ErrorActionPreference = "Continue"
$WorkingDir = "c:\Users\soham\OneDrive\Desktop\Food Scanner"
$FlutterBat = "C:\flutter\bin\flutter.bat"
$StdOutLog = Join-Path $WorkingDir "flutter_web_stdout.log"
$StdErrLog = Join-Path $WorkingDir "flutter_web_stderr.log"
$PidFile = Join-Path $WorkingDir "flutter_server.pid"

Write-Host "Starting Flutter web server..."
Write-Host "Working dir: $WorkingDir"
Write-Host "Flutter: $FlutterBat"

$ArgsList = @(
    "run",
    "-d", "web-server",
    "--web-port=8080",
    "--web-hostname=0.0.0.0"
)

$Process = Start-Process -FilePath $FlutterBat -ArgumentList $ArgsList `
    -WorkingDirectory $WorkingDir `
    -RedirectStandardOutput $StdOutLog `
    -RedirectStandardError $StdErrLog `
    -WindowStyle Hidden `
    -PassThru

$Pid = $Process.Id
Write-Host "Launched server process with PID: $Pid"
$Pid | Out-File -FilePath $PidFile -Encoding ASCII

Write-Host "Waiting 25 seconds for the server to boot..."
$Timeout = 25
$Elapsed = 0
$ServerReady = $false

while ($Elapsed -lt $Timeout) {
    Start-Sleep -Seconds 2
    $Elapsed += 2

    try {
        $Response = Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        Write-Host "[$Elapsed`s] Server responded with HTTP $($Response.StatusCode)"
        $ServerReady = $true
        break
    } catch {
        $Status = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "no-connect" }
        Write-Host "[$Elapsed`s] Not ready yet: $Status"
    }
}

if ($ServerReady) {
    Write-Host "=== SUCCESS: Flutter web server is running ==="
    Write-Host "PID: $Pid"
    Write-Host "URL: http://localhost:8080"
} else {
    Write-Host "=== WARNING: Server not confirmed after $Timeout seconds ==="
    Write-Host "PID: $Pid (process may still be starting)"
    Write-Host "Check logs: $StdOutLog / $StdErrLog"
}

exit 0
