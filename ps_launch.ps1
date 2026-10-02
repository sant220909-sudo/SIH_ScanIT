$marker = "c:\Users\soham\OneDrive\Desktop\Food Scanner\ps_marker.txt"
"START $(Get-Date -Format 'o')" | Out-File -FilePath $marker -Encoding utf8

$wd = "c:\Users\soham\OneDrive\Desktop\Food Scanner"
$fb = "C:\flutter\bin\flutter.bat"
$out = Join-Path $wd "flutter_web_stdout.log"
$err = Join-Path $wd "flutter_web_stderr.log"
$pidfile = Join-Path $wd "flutter_server.pid"

$args = @('run','-d','web-server','--web-port=8080','--web-hostname=0.0.0.0')

"ABOUT_TO_START_PROCESS" | Add-Content $marker

try {
    $p = Start-Process -FilePath $fb -ArgumentList $args `
        -WorkingDirectory $wd `
        -RedirectStandardOutput $out `
        -RedirectStandardError $err `
        -WindowStyle Hidden `
        -UseNewEnvironment `
        -PassThru

    $id = $p.Id
    "STARTED PID=$id" | Add-Content $marker
    $id | Out-File -FilePath $pidfile -Encoding ascii
} catch {
    "ERROR $_" | Add-Content $marker
}

"DONE $(Get-Date -Format 'o')" | Add-Content $marker
exit 0
