@echo off
setlocal
set "ROOT=%~dp0..\.."
set "ENV_FILE=%~dp0.env"
set "PYTHON=%ROOT%\.venv\Scripts\python.exe"

if not exist "%ENV_FILE%" (
  echo Missing %ENV_FILE%
  echo Run: Copy-Item deployment\windows\.env.example deployment\windows\.env
  exit /b 1
)

if not exist "%PYTHON%" (
  echo Missing virtual environment. Follow deployment\windows\README.md first.
  exit /b 1
)

set "BIOSBORKA_ENV_FILE=%ENV_FILE%"
"%PYTHON%" "%~dp0run_waitress.py"
