@echo off
setlocal
cd /d "%~dp0"

echo WARNING: This removes every BioSborka user, laboratory and experiment.
echo The Oracle Docker volume will be deleted permanently.
set /p CONFIRM=Type DELETE to continue:
if /I not "%CONFIRM%"=="DELETE" (
  echo Reset cancelled.
  exit /b 0
)

docker compose down -v --remove-orphans
if errorlevel 1 exit /b 1

docker compose up --build -d
if errorlevel 1 exit /b 1

set "GAME_PORT=8000"
for /f "usebackq tokens=1,* delims==" %%A in (".env") do if /I "%%A"=="WEB_PORT" set "GAME_PORT=%%B"
if defined WEB_PORT set "GAME_PORT=%WEB_PORT%"

echo Clean installation started. Open http://127.0.0.1:%GAME_PORT% after web becomes healthy.
endlocal
