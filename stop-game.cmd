@echo off
setlocal
cd /d "%~dp0"

docker compose stop
if errorlevel 1 exit /b 1

echo BioSborka containers are stopped. Oracle data was preserved.
endlocal
