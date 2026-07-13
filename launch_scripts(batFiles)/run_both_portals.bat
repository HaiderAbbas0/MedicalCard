@echo off
echo ===================================================
echo Starting Hayaat ID - Admin and Staff Portals
echo ===================================================

:: Navigate to the directory of this script to avoid path issues
cd /d "%~dp0"

echo Starting Admin Web App in a new window (Vite port 5173)...
start "Hayaat ID - Admin Web App" cmd /c "call run_web_admin.bat"

echo Starting Staff Web App in a new window (Vite port 5174)...
start "Hayaat ID - Staff Web App" cmd /c "call run_web_staff.bat"

echo.
echo Both portals have been launched in separate windows!
echo Keep those windows open to keep the servers running.
echo.
pause
