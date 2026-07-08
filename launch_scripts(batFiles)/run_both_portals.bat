@echo off
echo ===================================================
echo Starting CNIC Health Card - Admin and Staff Portals
echo ===================================================

:: Navigate to the directory of this script to avoid path issues
cd /d "%~dp0"

echo Starting Admin Web App in a new window (Vite port 5173)...
start "CNIC Health Card - Admin Web App" cmd /c "call run_web_admin.bat"

echo Starting Staff Web App in a new window (Vite port 5174)...
start "CNIC Health Card - Staff Web App" cmd /c "call run_web_staff.bat"

echo.
echo Both portals have been launched in separate windows!
echo Keep those windows open to keep the servers running.
echo.
pause
