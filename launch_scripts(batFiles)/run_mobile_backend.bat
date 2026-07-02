@echo off
echo ===================================================
echo Running SehatID Backend for Mobile Client
echo ===================================================

cd /d "%~dp0..\backend"
echo Installing backend dependencies...
call npm install

echo Starting backend server on port 3000...
call npm start
pause
