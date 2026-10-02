@echo off
echo %date% %time% - Starting flutter --version... > "%~dp0quick_test.log"
"C:\flutter\bin\flutter.bat" --version >> "%~dp0quick_test.log" 2>&1
echo Exit code: %ERRORLEVEL% >> "%~dp0quick_test.log"
echo %date% %time% - Done. >> "%~dp0quick_test.log"
