$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$python = Join-Path $root '.venv\Scripts\python.exe'
$envFile = Join-Path $PSScriptRoot '.env'

if (-not (Test-Path $python)) { throw 'Не найдена .venv. Сначала выполните deployment\windows\setup.ps1.' }
if (-not (Test-Path $envFile)) { throw 'Не найден deployment\windows\.env. Скопируйте .env.example и заполните параметры Oracle.' }

$env:BIOSBORKA_ENV_FILE = $envFile
Write-Host 'Адрес игры задаётся параметрами FLASK_HOST и FLASK_PORT в deployment\windows\.env.'
& $python (Join-Path $PSScriptRoot 'run_waitress.py')
