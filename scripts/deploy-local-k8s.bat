@echo off
setlocal

cd /d "%~dp0"

set "CLUSTER_NAME=mazebank"
set "HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts"
set "LOG_DIR=%~dp0logs"
set "LOG_FILE=%LOG_DIR%\local-k8s-deploy.log"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
break > "%LOG_FILE%"

call :log "Inicio do deploy local Kubernetes"
call :log "Cluster: %CLUSTER_NAME%"

echo [1/10] Verificando Docker...
call :log "Verificando Docker"
docker info >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  echo Docker nao esta em execucao. Abra o Docker Desktop e tente novamente.
  call :fail "Docker nao esta em execucao"
  exit /b 1
)

echo [2/10] Verificando kind...
call :log "Verificando kind"
kind version >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  echo kind nao encontrado. Instale o kind e tente novamente.
  call :fail "kind nao encontrado"
  exit /b 1
)

echo [3/10] Verificando kubectl...
call :log "Verificando kubectl"
kubectl version --client >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  echo kubectl nao encontrado. Instale o kubectl e tente novamente.
  call :fail "kubectl nao encontrado"
  exit /b 1
)

echo [4/10] Criando ou reutilizando cluster kind...
call :log "Criando ou reutilizando cluster kind"

set "CLUSTER_EXISTS="
for /f %%i in ('kind get clusters 2^>nul') do (
  if /i "%%i"=="%CLUSTER_NAME%" set "CLUSTER_EXISTS=1"
)

if defined CLUSTER_EXISTS (
  echo Cluster %CLUSTER_NAME% ja existe.
  call :log "Cluster %CLUSTER_NAME% ja existe"
) else (
  kind create cluster --name %CLUSTER_NAME% --config k8s\local\kind-config.yaml >> "%LOG_FILE%" 2>&1
  if errorlevel 1 (
    echo Falha ao criar o cluster kind.
    call :fail "Falha ao criar o cluster kind"
    exit /b 1
  )
)

kubectl config use-context kind-%CLUSTER_NAME% >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  echo Falha ao selecionar o contexto do cluster.
  call :fail "Falha ao selecionar o contexto do cluster"
  exit /b 1
)

echo [5/10] Instalando ingress-nginx...
call :log "Instalando ingress-nginx"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  echo Falha ao instalar o ingress-nginx.
  call :fail "Falha ao instalar o ingress-nginx"
  exit /b 1
)

echo [6/10] Aguardando ingress-nginx ficar pronto...
call :log "Aguardando ingress-nginx ficar pronto"
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  echo O ingress-nginx nao ficou pronto no tempo esperado.
  call :log "Capturando diagnostico do ingress-nginx"
  kubectl get pods -n ingress-nginx -o wide >> "%LOG_FILE%" 2>&1
  kubectl describe pods -n ingress-nginx >> "%LOG_FILE%" 2>&1
  call :fail "Ingress-nginx nao ficou pronto"
  exit /b 1
)

echo [7/10] Gerando imagem Docker local...
call :log "Gerando imagem Docker local"
docker build --no-cache -t mazebank:local . >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  echo Falha ao gerar a imagem Docker.
  call :fail "Falha ao gerar a imagem Docker"
  exit /b 1
)

echo [8/10] Carregando imagem no cluster kind...
call :log "Carregando imagem no cluster kind"
kind load docker-image mazebank:local --name %CLUSTER_NAME% >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  echo Falha ao carregar a imagem no cluster kind.
  call :fail "Falha ao carregar a imagem no cluster kind"
  exit /b 1
)

echo [9/10] Aplicando manifests Kubernetes...
call :log "Aplicando manifests Kubernetes locais"
kubectl apply -k k8s/overlays/local >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  echo Falha ao aplicar os manifests Kubernetes.
  call :fail "Falha ao aplicar os manifests Kubernetes"
  exit /b 1
)

call :log "Forcando rollout da aplicacao"
kubectl rollout restart deployment/mazebank -n mazebank >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  echo Falha ao reiniciar o deployment da aplicacao.
  call :fail "Falha ao reiniciar o deployment da aplicacao"
  exit /b 1
)

echo [10/10] Aguardando a aplicacao ficar pronta...
call :log "Aguardando rollout do Mongo"
kubectl rollout status deployment/mongo -n mazebank --timeout=180s >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  echo Mongo nao ficou pronto no tempo esperado.
  call :log "Capturando diagnostico do Mongo"
  kubectl get pods -n mazebank -o wide >> "%LOG_FILE%" 2>&1
  kubectl describe deployment mongo -n mazebank >> "%LOG_FILE%" 2>&1
  kubectl describe pods -n mazebank >> "%LOG_FILE%" 2>&1
  kubectl logs -n mazebank deploy/mongo >> "%LOG_FILE%" 2>&1
  call :fail "Mongo nao ficou pronto"
  exit /b 1
)
call :log "Aguardando rollout da aplicacao"
kubectl rollout status deployment/mazebank -n mazebank --timeout=180s >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  echo Aplicacao nao ficou pronta no tempo esperado.
  call :log "Capturando diagnostico da aplicacao"
  kubectl get pods -n mazebank -o wide >> "%LOG_FILE%" 2>&1
  kubectl describe deployment mazebank -n mazebank >> "%LOG_FILE%" 2>&1
  kubectl describe pods -n mazebank >> "%LOG_FILE%" 2>&1
  kubectl logs -n mazebank deploy/mazebank >> "%LOG_FILE%" 2>&1
  call :fail "Aplicacao nao ficou pronta"
  exit /b 1
)

echo Atualizando hosts local para mazebank.local...
call :log "Atualizando arquivo hosts"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$hosts = '%HOSTS_FILE%';" ^
  "$entry = '127.0.0.1 mazebank.local';" ^
  "$content = Get-Content -Path $hosts -ErrorAction Stop;" ^
  "if ($content -notcontains $entry) { Add-Content -Path $hosts -Value $entry -ErrorAction Stop }" >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  echo Nao foi possivel atualizar o arquivo hosts automaticamente.
  echo Adicione manualmente esta linha em %HOSTS_FILE%:
  echo 127.0.0.1 mazebank.local
  call :log "Falha ao atualizar o arquivo hosts automaticamente"
)

echo.
echo Cluster local pronto.
echo URL da aplicacao: http://mazebank.local/mazebank/actuator/health
echo Log de execucao: %LOG_FILE%
call :log "Deploy concluido com sucesso"
echo.
echo Comandos uteis:
echo   kubectl get pods -n mazebank
echo   kubectl get ingress -n mazebank
echo   kubectl logs -n mazebank deploy/mazebank
echo   scripts\k8s-debug-local.bat start   # Mongo no host + IntelliJ (.env.local.example)
echo   kind delete cluster --name %CLUSTER_NAME%

endlocal
exit /b 0

:log
echo [%date% %time%] %~1>> "%LOG_FILE%"
goto :eof

:fail
echo.
echo Erro: %~1
echo Analise o arquivo de log em:
echo %LOG_FILE%
call :log "ERRO: %~1"
goto :eof
