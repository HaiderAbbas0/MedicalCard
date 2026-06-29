@echo off
echo ===================================================
echo Starting CNIC Health Card - Admin Web App
echo ===================================================

echo [1/2] Starting Backend Server in a new window...
start "SehatID Backend" /D "%~dp0..\backend" cmd /k "echo Installing backend dependencies... && call npm install && echo Starting backend server... && npm start"

echo [2/2] Starting Admin Frontend in this window...
cd /d "%~dp0..\web-admin"
echo Installing admin frontend dependencies...
call npm install
echo Starting admin frontend on http://localhost:5173...
call npm run dev
pause
