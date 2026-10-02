@echo off
set PATH=C:\flutter\bin;%PATH%
cd /d "c:\Users\soham\OneDrive\Desktop\Food Scanner"
echo Running flutter build web...
flutter build web --release > flutter_build.log 2>&1
echo Build complete. Exit code: %ERRORLEVEL%
echo --- LOG CONTENTS ---
type flutter_build.log
echo --- END LOG ---
