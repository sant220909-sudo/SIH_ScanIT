@echo off
setlocal

echo === Starting Flutter Web Setup ===
echo Date: %date% %time%
echo Working Dir: %cd%
echo.

echo [1/3] Creating web platform files...
call "C:\flutter\bin\flutter.bat" create . --platforms=web >> "c:\Users\soham\OneDrive\Desktop\Food Scanner\flutter_setup.log" 2>&1
echo Step 1 exit code: %ERRORLEVEL%
echo.

echo [2/3] Running flutter pub get...
call "C:\flutter\bin\flutter.bat" pub get >> "c:\Users\soham\OneDrive\Desktop\Food Scanner\flutter_setup.log" 2>&1
echo Step 2 exit code: %ERRORLEVEL%
echo.

echo [3/3] Starting web server on port 8080...
echo This will run in background...
start "FlutterWebServer" /B cmd /c ""C:\flutter\bin\flutter.bat" run -d web-server --web-port=8080 --web-hostname=0.0.0.0 >> "c:\Users\soham\OneDrive\Desktop\Food Scanner\flutter_server.log" 2>&1"
echo Server launch initiated.
echo.
echo Setup complete. Check flutter_setup.log and flutter_server.log for details.
endlocal
