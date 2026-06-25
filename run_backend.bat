@echo off
cd backend
echo Installing backend dependencies...
call npm install
echo Starting backend server on port 3000...
node server.js
pause
