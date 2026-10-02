@echo off
setlocal
cd /d "c:\Users\soham\OneDrive\Desktop\Food Scanner"

set "PIDFILE=%cd%\flutter_server.pid"
set "STDOUTLOG=%cd%\flutter_web_stdout.log"
set "STDERRLOG=%cd%\flutter_web_stderr.log"
set "MARKER=%cd%\launcher_marker.txt"

echo Launcher started at %date% %time% > "%MARKER%"
echo CWD=%cd% >> "%MARKER%"

echo Starting detached Flutter web server...
start "FlutterWebServer" /MIN /D "c:\Users\soham\OneDrive\Desktop\Food Scanner" cmd /C ""C:\flutter\bin\flutter.bat" run -d web-server --web-port=8080 --web-hostname=0.0.0.0 >> "%STDOUTLOG%" 2>> "%STDERRLOG%""

echo Launcher finished at %date% %time% >> "%MARKER%"
echo start command issued - process should now be running independently. >> "%MARKER%"

endlocal
exit /b 0
