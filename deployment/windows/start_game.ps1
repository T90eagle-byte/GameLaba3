$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$python = Join-Path $root '.venv\Scripts\python.exe'
$envFile = Join-Path $PSScriptRoot '.env'

if (-not (Test-Path $python)) { throw 'Не найдена .venv. Сначала выполните deployment\windows\setup.ps1.' }
if (-not (Test-Path $envFile)) { throw 'Не найден deployment\windows\.env. Скопируйте .env.example и заполните параметры Oracle.' }

$env:BIOSBORKA_ENV_FILE = $envFile
Write-Host 'Игра будет доступна по адресу http://127.0.0.1:8000'
& $python (Join-Path $PSScriptRoot 'run_waitress.py')
