@echo off
setlocal

:: Launcher Windows do deploy no Azure AKS via WSL.
::
:: A logica de execucao vive em scripts/deploy-azure-aks.sh e roda dentro do WSL Ubuntu,
:: onde az cli, kubectl e helm estao configurados.
::
:: Uso:
::   deploy-azure-aks.bat [deploy [real|local] [opcoes] | status | logs | destroy | help]
::
:: Exemplos:
::   scripts\deploy-azure-aks.bat deploy real
::   scripts\deploy-azure-aks.bat status
::   scripts\deploy-azure-aks.bat logs

where.exe wsl >nul 2>&1
if errorlevel 1 goto no_wsl

set "WSL_SCRIPT="
for /f "usebackq delims=" %%p in (`wsl wslpath -a "%~dp0deploy-azure-aks.sh"`) do set "WSL_SCRIPT=%%p"
if not defined WSL_SCRIPT (
  echo Erro: nao foi possivel resolver "%~dp0deploy-azure-aks.sh" dentro do WSL.
  exit /b 1
)

wsl bash -c "'%WSL_SCRIPT%' %*"
exit /b %errorlevel%

:no_wsl
echo Erro: WSL nao encontrado.
echo Certifique-se de que o WSL esta instalado e funcionando.
exit /b 1
