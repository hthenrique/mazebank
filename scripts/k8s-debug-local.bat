@echo off
setlocal

REM Publica o Mongo do Kind (namespace mongodb) em localhost para debug no IntelliJ/Maven.

set "NAMESPACE=mongodb"
if "%MONGO_LOCAL_PORT%"=="" set "MONGO_LOCAL_PORT=27017"
if "%APP_LOCAL_PORT%"=="" set "APP_LOCAL_PORT=8080"
set "PID_FILE=%TEMP%\mazebank-mongo-port-forward.pid"

if "%~1"=="" goto usage
if /i "%~1"=="start" goto start
if /i "%~1"=="stop" goto stop
if /i "%~1"=="status" goto status
goto usage

:usage
echo Uso: %~nx0 ^<start^|stop^|status^>
echo.
echo   start   Publica Mongo do Kind em localhost:%MONGO_LOCAL_PORT% ^(app no cluster continua^)
echo   stop    Encerra o port-forward
echo   status  Mostra estado do port-forward e dos pods
echo.
echo IntelliJ: use as variaveis:
echo   PORT=%APP_LOCAL_PORT%
echo   SPRING_PROFILES_ACTIVE=local
echo   MONGO_CONNECTION_URL=mongodb://mazebank-user:mazebank@127.0.0.1:%MONGO_LOCAL_PORT%/mazebank?authSource=admin
exit /b 1

:start
kubectl version --client >nul 2>&1
if errorlevel 1 (
  echo kubectl nao encontrado.
  exit /b 1
)

kubectl get ns %NAMESPACE% >nul 2>&1
if errorlevel 1 (
  echo Namespace %NAMESPACE% nao encontrado. Rode deploy-local-k8s.bat antes.
  exit /b 1
)

call :stop_port_forward

echo Publicando Mongo do Kind (%NAMESPACE%) em 127.0.0.1:%MONGO_LOCAL_PORT%...
start "" /b cmd /c "kubectl -n %NAMESPACE% port-forward svc/mazebank-cluster-svc %MONGO_LOCAL_PORT%:27017 >nul 2>&1"
timeout /t 1 /nobreak >nul

for /f "tokens=2" %%p in ('tasklist /fi "imagename eq kubectl.exe" /fo list ^| findstr /i "PID:"') do (
  echo %%p>"%PID_FILE%"
  goto after_pid
)
:after_pid

echo.
echo Mongo local pronto: mongodb://mazebank-user:mazebank@127.0.0.1:%MONGO_LOCAL_PORT%/mazebank?authSource=admin
echo App no Kind:        http://mazebank.local/mazebank/actuator/health
echo.
echo No IntelliJ, use as variaveis:
echo   PORT=%APP_LOCAL_PORT%
echo   SPRING_PROFILES_ACTIVE=local
echo   MONGO_CONNECTION_URL=mongodb://mazebank-user:mazebank@127.0.0.1:%MONGO_LOCAL_PORT%/mazebank?authSource=admin
echo.
echo Quando terminar:
echo   %~nx0 stop
exit /b 0

:stop
echo Encerrando port-forward do Mongo...
call :stop_port_forward
echo Port-forward encerrado. App no Kind permanece: http://mazebank.local/mazebank/actuator/health
exit /b 0

:status
echo === port-forward ===
if exist "%PID_FILE%" (
  echo arquivo pid presente: %PID_FILE%
) else (
  echo inativo
)
echo.
echo === pods ^(%NAMESPACE%^) ===
kubectl get pods -n %NAMESPACE% -o wide
exit /b 0

:stop_port_forward
if exist "%PID_FILE%" del /f /q "%PID_FILE%" >nul 2>&1
for /f "tokens=2" %%p in ('tasklist /fi "imagename eq kubectl.exe" /fo list ^| findstr /i "PID:"') do (
  wmic process where "ProcessId=%%p" get CommandLine 2>nul | findstr /i "port-forward svc/mazebank-cluster-svc" >nul
  if not errorlevel 1 taskkill /PID %%p /F >nul 2>&1
)
goto :eof
