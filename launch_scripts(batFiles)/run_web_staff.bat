@echo off
echo ===================================================
echo Starting CNIC Health Card - Staff Web App
echo ===================================================

echo [1/2] Starting Backend Server in a new window...
start "SehatID Backend" /D "%~dp0..\backend" cmd /k "echo Installing backend dependencies... && call npm install && echo Starting backend server... && npm start"

echo [2/2] Starting Staff Frontend in this window...
cd /d "%~dp0..\web-staff"
echo Installing staff frontend dependencies...
call npm install
echo Starting staff frontend on http://localhost:5174...
call npm run dev
pause
