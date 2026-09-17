$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$python = Join-Path $root '.venv\Scripts\python.exe'
$requirements = Join-Path $PSScriptRoot 'requirements-windows.txt'

if (-not (Test-Path $python)) {
    if (Get-Command py -ErrorAction SilentlyContinue) {
        & py -3.12 -m venv (Join-Path $root '.venv')
    }
    elseif (Get-Command python -ErrorAction SilentlyContinue) {
        $version = & python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
        if ($version -ne '3.12') { throw "Нужен Python 3.12, обнаружен Python $version." }
        & python -m venv (Join-Path $root '.venv')
    }
    else {
        throw 'Не найден Python 3.12. Установите Python 3.12 x64 с официального сайта Python.'
    }
}

& $python -m pip install --upgrade pip
& $python -m pip install -r $requirements

Write-Host ''
Write-Host 'Среда готова. Создайте deployment\windows\.env из .env.example и заполните параметры Oracle.'
