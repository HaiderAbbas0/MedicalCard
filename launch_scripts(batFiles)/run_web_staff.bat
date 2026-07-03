@echo off
echo ===================================================
echo Starting CNIC Health Card - Staff Web App
echo ===================================================
echo (Talks directly to Supabase - there is no backend to start.)

cd /d "%~dp0..\web-staff"
echo Installing staff frontend dependencies...
call npm install
echo Starting staff frontend on http://localhost:5174...
call npm run dev
pause
