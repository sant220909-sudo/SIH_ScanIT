@echo off
setlocal enabledelayedexpansion

set "PROJDIR=c:\Users\soham\OneDrive\Desktop\Food Scanner"
set "LOGCREATE=%PROJDIR%\log_create.txt"
set "LOGPUB=%PROJDIR%\log_pubget.txt"
set "LOGSERVER=%PROJDIR%\log_server.txt"

echo ===== Create Web Platform ===== > "%LOGCREATE%"
echo Start: %date% %time% >> "%LOGCREATE%"
cd /d "%PROJDIR%"
echo CD: %cd% >> "%LOGCREATE%"
echo. >> "%LOGCREATE%"
call "C:\flutter\bin\flutter.bat" create . --platforms=web >> "%LOGCREATE%" 2>&1
set "ERR=%ERRORLEVEL%"
echo. >> "%LOGCREATE%"
echo Exit code: %ERR% >> "%LOGCREATE%"
echo End: %date% %time% >> "%LOGCREATE%"

echo ===== Pub Get ===== > "%LOGPUB%"
echo Start: %date% %time% >> "%LOGPUB%"
cd /d "%PROJDIR%"
echo CD: %cd% >> "%LOGPUB%"
echo. >> "%LOGPUB%"
call "C:\flutter\bin\flutter.bat" pub get >> "%LOGPUB%" 2>&1
set "ERR=%ERRORLEVEL%"
echo. >> "%LOGPUB%"
echo Exit code: %ERR% >> "%LOGPUB%"
echo End: %date% %time% >> "%LOGPUB%"

echo ===== Start Web Server ===== > "%LOGSERVER%"
echo Start: %date% %time% >> "%LOGSERVER%"
cd /d "%PROJDIR%"
echo CD: %cd% >> "%LOGSERVER%"
echo. >> "%LOGSERVER%"

start "" "cmd" /c ""C:\flutter\bin\flutter.bat" run -d web-server --web-port=8080 --web-hostname=0.0.0.0 >> "%LOGSERVER%" 2>&1"

echo Server launch command issued. >> "%LOGSERVER%"
echo End batch: %date% %time% >> "%LOGSERVER%"

endlocal
