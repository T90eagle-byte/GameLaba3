@echo off
setlocal
cd /d "%~dp0"

where docker >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Docker Desktop is not installed or docker.exe is not in PATH.
  exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Docker Desktop is not running. Start it in Linux containers mode.
  exit /b 1
)

if not exist ".env" (
  copy /Y ".env.example" ".env" >nul
  echo Created .env from .env.example.
  echo Review the passwords in .env before sharing this folder.
)

set "GAME_PORT=8000"
for /f "usebackq tokens=1,* delims==" %%A in (".env") do if /I "%%A"=="WEB_PORT" set "GAME_PORT=%%B"
if defined WEB_PORT set "GAME_PORT=%WEB_PORT%"

docker compose up --build -d
if errorlevel 1 (
  echo [ERROR] Containers did not start. Run: docker compose logs --tail=200
  exit /b 1
)

echo.
echo BioSborka is starting. The first Oracle launch can take several minutes.
echo Open: http://127.0.0.1:%GAME_PORT%
echo Check status: docker compose ps
endlocal
