$ErrorActionPreference = "Continue"
Write-Host "=== PowerShell Diagnostic Script ==="
Write-Host "Current Directory: $(Get-Location)"
Write-Host "User: $env:USERNAME"
Write-Host "Temp: $env:TEMP"
Write-Host ""

Write-Host "--- Test 1: Create marker in TEMP ---"
$markerPath = Join-Path $env:TEMP "flutter_marker_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
"Test marker created at $(Get-Date)" | Out-File -FilePath $markerPath -Encoding utf8
Write-Host "Marker created: $markerPath"
Write-Host "Exists: $(Test-Path $markerPath)"
Write-Host ""

Write-Host "--- Test 2: Check Flutter exists ---"
$flutterPath = "C:\flutter\bin\flutter.bat"
Write-Host "Flutter path: $flutterPath"
Write-Host "Exists: $(Test-Path $flutterPath)"
Write-Host ""

if (Test-Path $flutterPath) {
    Write-Host "--- Test 3: Run flutter --version ---"
    $logFile = Join-Path $env:TEMP "flutter_version_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    Write-Host "Log file: $logFile"
    & $flutterPath --version 2>&1 | Tee-Object -FilePath $logFile
    Write-Host "Exit code: $LASTEXITCODE"
    Write-Host "Log exists: $(Test-Path $logFile)"
    if (Test-Path $logFile) {
        Write-Host "Log contents:"
        Get-Content $logFile
    }
}
Write-Host ""
Write-Host "=== Done ==="
