@echo off
set PATH=C:\flutter\bin;%PATH%
cd /d "c:\Users\soham\OneDrive\Desktop\Food Scanner"
flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0 2>&1
