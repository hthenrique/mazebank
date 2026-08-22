@echo off
setlocal

:: Launcher Windows do ambiente local em Kind.
::
:: A logica vive em scripts/deploy-local-k8s.sh e roda dentro do WSL: kind e helm
:: normalmente nao estao instalados nativamente no Windows, e o Docker Desktop ja
:: compartilha o daemon com a distro. Este arquivo so resolve o caminho, cuida do
:: hosts do Windows e repassa os argumentos.
::
:: Uso: deploy-local-k8s.bat [deploy [local^|real] [--debug] ^| debug start^|stop^|status ^| help]

set "HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts"
set "APP_HOST=mazebank.local"

where.exe wsl >nul 2>&1
if errorlevel 1 goto no_wsl

set "WSL_SCRIPT="
for /f "usebackq delims=" %%p in (`wsl wslpath -a "%~dp0deploy-local-k8s.sh"`) do set "WSL_SCRIPT=%%p"
if not defined WSL_SCRIPT (
  echo Erro: nao foi possivel resolver "%~dp0deploy-local-k8s.sh" dentro do WSL.
  exit /b 1
)

:: O /etc/hosts do WSL nao resolve nomes para o navegador do Windows, entao a
:: entrada de hosts e responsabilidade deste wrapper (so faz sentido no deploy).
if /i not "%~1"=="debug" if /i not "%~1"=="help" call :update_hosts

wsl bash -c "'%WSL_SCRIPT%' %*"
exit /b %errorlevel%

:update_hosts
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$hosts = '%HOSTS_FILE%';" ^
  "$entry = '127.0.0.1 %APP_HOST%';" ^
  "$content = Get-Content -Path $hosts -ErrorAction Stop;" ^
  "if ($content -notcontains $entry) { Add-Content -Path $hosts -Value $entry -ErrorAction Stop }" >nul 2>&1
if errorlevel 1 (
  echo [AVISO] Nao foi possivel atualizar o arquivo hosts automaticamente.
  echo         Rode este script como Administrador, ou adicione manualmente em
  echo         %HOSTS_FILE% a linha:
  echo         127.0.0.1 %APP_HOST%
  echo.
)
goto :eof

:no_wsl
echo Erro: WSL nao encontrado.
echo.
echo Este wrapper delega a execucao para scripts/deploy-local-k8s.sh dentro do WSL,
echo porque kind e helm normalmente nao estao instalados nativamente no Windows.
echo.
echo Opcoes:
echo   1^) Instale o WSL:  wsl --install
echo   2^) Ou rode ./scripts/deploy-local-k8s.sh direto em um shell Linux/Git Bash
echo      com docker, kind, kubectl e helm no PATH.
exit /b 1
