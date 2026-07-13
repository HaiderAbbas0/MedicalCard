@echo off
echo ===================================================
echo Starting Hayaat ID - Admin Web App
echo ===================================================
echo (Talks directly to Supabase - there is no backend to start.)

cd /d "%~dp0..\web-admin"
echo Installing admin frontend dependencies...
call npm install
echo Starting admin frontend on http://localhost:5173...
call npm run dev
pause
