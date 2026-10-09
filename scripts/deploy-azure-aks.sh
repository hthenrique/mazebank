#!/usr/bin/env bash
set -euo pipefail

# Garante acesso a ferramentas instaladas no diretorio do usuario no WSL (ex: kubectl, helm, kubelogin)
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

# Se docker nativo nao estiver respondendo, mas docker.exe estiver no PATH do Windows
if ! docker info >/dev/null 2>&1 && command -v docker.exe >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/bin"
  cat <<'EOF_DOCKER' > "$HOME/.local/bin/docker"
#!/usr/bin/env bash
exec docker.exe "$@"
EOF_DOCKER
  chmod +x "$HOME/.local/bin/docker"
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Valores padrao para Azure / AKS
AZ_RESOURCE_GROUP="${AZ_RESOURCE_GROUP:-MyResourceGroupAKS-BR}"
AZ_CLUSTER_NAME="${AZ_CLUSTER_NAME:-MyClusterAKS}"
AZ_ACR_NAME="${AZ_ACR_NAME:-mazebankacr}"
AZ_LOCATION="${AZ_LOCATION:-brazilsouth}"

APP_NAMESPACE="mazebank"
APP_RELEASE="mazebank"
DEFAULT_ENV="real"
SKIP_BUILD=0
USE_LOCAL_DOCKER=0
CUSTOM_TAG=""

LOG_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOG_DIR/azure-aks-deploy.log"

log() {
  mkdir -p "$LOG_DIR"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

fail() {
  echo
  echo "❌ Erro: $*"
  echo "Analise o arquivo de log em: $LOG_FILE"
  log "ERRO: $*"
  exit 1
}

usage() {
  cat <<EOF
Uso: $0 [comando] [ambiente] [opcoes]

Comandos:
  deploy [real|local]     Executa o ciclo completo de build e deploy no AKS (padrao)
  status                  Verifica o status dos pods, services e ingress no AKS
  logs                    Exibe e acompanha os logs da aplicacao no cluster
  destroy                 Remove a aplicacao Helm e o namespace do AKS
  help                    Exibe esta ajuda

Opcoes:
  --skip-build            Pula a etapa de build da imagem no ACR
  --local-docker          Usa o Docker local para build/push em vez do Azure ACR Build
  --acr <nome>            Define o nome do Azure Container Registry (padrao: ${AZ_ACR_NAME})
  --rg <nome>             Define o Resource Group no Azure (padrao: ${AZ_RESOURCE_GROUP})
  --cluster <nome>        Define o nome do cluster AKS (padrao: ${AZ_CLUSTER_NAME})
  --tag <versao>          Define uma tag customizada para a imagem (padrao: versao do pom.xml)

Exemplos:
  $0 deploy real
  $0 deploy real --skip-build
  $0 status
  $0 logs
EOF
}

get_project_version() {
  if [ -f "$ROOT_DIR/pom.xml" ]; then
    local ver
    ver=$(grep -m1 '<version>' "$ROOT_DIR/pom.xml" | sed -E 's/.*<version>([^<]+)<\/version>.*/\1/' || true)
    if [ -n "$ver" ]; then
      echo "$ver"
      return 0
    fi
  fi
  echo "v1.0.0"
}

check_prereqs() {
  log "Verificando ferramentas necessarias no WSL..."

  if ! command -v az >/dev/null 2>&1; then
    fail "Azure CLI (az) nao encontrado no WSL. Instale via: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
  fi

  if ! kubectl version --client >/dev/null 2>&1; then
    fail "kubectl nao encontrado no WSL. Certifique-se de que esta em \$HOME/.local/bin ou /usr/local/bin"
  fi

  if ! helm version --short >/dev/null 2>&1; then
    fail "helm nao encontrado no WSL. Certifique-se de que esta em \$HOME/.local/bin ou /usr/local/bin"
  fi
}

check_azure_auth() {
  log "Validando sessao do Azure CLI..."
  if ! az account show >/dev/null 2>&1; then
    echo "⚠️  Voce nao esta autenticado no Azure CLI."
    echo "Executando 'az login'..."
    az login --use-device-code || fail "Falha na autenticacao do Azure CLI."
  fi

  local sub_name sub_id
  sub_name=$(az account show --query "name" -o tsv)
  sub_id=$(az account show --query "id" -o tsv)
  echo "✔ Conectado a Azure: $sub_name ($sub_id)"
  log "Assinatura ativa: $sub_name ($sub_id)"
}

check_resource_providers() {
  log "Verificando registro do provedor Microsoft.ContainerRegistry..."
  local reg_state
  reg_state=$(az provider show -n Microsoft.ContainerRegistry --query "registrationState" -o tsv 2>/dev/null || echo "NotRegistered")

  if [ "$reg_state" != "Registered" ]; then
    echo "Registrando provedor 'Microsoft.ContainerRegistry' na sua assinatura Azure..."
    az provider register --namespace Microsoft.ContainerRegistry >>"$LOG_FILE" 2>&1 || true
    echo -n "Aguardando confirmacao do registro no Azure"
    while [ "$reg_state" != "Registered" ]; do
      echo -n "."
      sleep 4
      reg_state=$(az provider show -n Microsoft.ContainerRegistry --query "registrationState" -o tsv 2>/dev/null || echo "NotRegistered")
    done
    echo " ✔ Registrado!"
  else
    log "Provedor Microsoft.ContainerRegistry ja registrado."
  fi
}

resolve_acr() {
  local rg="$1"
  local acr_req="$2"

  # Verifica se o ACR ja existe no Resource Group
  local existing_acr
  existing_acr=$(az acr list -g "$rg" --query "[0].name" -o tsv 2>/dev/null || true)

  if [ -n "$existing_acr" ]; then
    echo "$existing_acr"
    return 0
  fi

  echo "$acr_req"
}

ensure_acr() {
  local rg="$1"
  local acr="$2"
  local loc="$3"
  local cluster="$4"

  log "Verificando se o ACR '$acr' existe no Resource Group '$rg'..."
  if ! az acr show -n "$acr" -g "$rg" >/dev/null 2>&1; then
    # Checa disponibilidade do nome no Azure
    local name_avail
    name_avail=$(az acr check-name -n "$acr" --query "nameAvailable" -o tsv 2>/dev/null || echo "true")
    if [ "$name_avail" = "false" ]; then
      local reason
      reason=$(az acr check-name -n "$acr" --query "message" -o tsv 2>/dev/null || echo "Nome ja em uso.")
      fail "O nome de ACR '$acr' nao esta disponivel: $reason. Utilize --acr <outro_nome>."
    fi

    echo "Criando Azure Container Registry '$acr' (SKU Basic, localizacao: $loc)..."
    log "Criando ACR $acr..."
    if ! az acr create -g "$rg" -n "$acr" --sku Basic --location "$loc" --admin-enabled true >>"$LOG_FILE" 2>&1; then
      fail "Falha ao criar o Azure Container Registry '$acr'. Verifique o log para detalhes."
    fi
    echo "✔ ACR '$acr' criado com sucesso!"
  else
    echo "✔ ACR '$acr' ja existe."
  fi

  # Garante permissao de Pull para o AKS
  echo "Verificando vinculo entre AKS '$cluster' e ACR '$acr'..."
  log "Executando --attach-acr no AKS..."
  if ! az aks update -g "$rg" -n "$cluster" --attach-acr "$acr" >>"$LOG_FILE" 2>&1; then
    log "Aviso: az aks update --attach-acr retornou status nao-zero (pode ja estar vinculado). Continuando..."
  else
    echo "✔ AKS vinculado ao ACR com permissao de pull."
  fi
}

build_and_push_image() {
  local acr="$1"
  local tag="$2"

  local image_name="${acr}.azurecr.io/mazebank:${tag}"
  echo
  echo "=========================================================="
  echo "  Construindo e publicando a imagem: $image_name"
  echo "=========================================================="

  if [ "$USE_LOCAL_DOCKER" -eq 1 ]; then
    echo "Usando Docker local para build e push..."
    log "Efetuando login no ACR via Docker..."
    az acr login -n "$acr" >>"$LOG_FILE" 2>&1

    log "Build da imagem Docker local..."
    docker build -t "$image_name" . | tee -a "$LOG_FILE"

    log "Push da imagem para o ACR..."
    docker push "$image_name" | tee -a "$LOG_FILE"
  else
    echo "Executando Azure Container Registry Cloud Build (az acr build)..."
    echo "(Nao depende do Docker Desktop local estar em execucao)"
    log "Disparando az acr build..."
    if ! az acr build --registry "$acr" --image "mazebank:${tag}" . | tee -a "$LOG_FILE"; then
      fail "Falha no build/push da imagem no ACR."
    fi
  fi

  echo "✔ Imagem publicada com sucesso: $image_name"
}

cmd_deploy() {
  local target_env="$1"
  local env_file="$ROOT_DIR/ENV/$target_env/env.conf"

  if [ ! -f "$env_file" ]; then
    fail "Arquivo de ambiente nao encontrado: $env_file"
  fi

  local image_tag
  if [ -n "$CUSTOM_TAG" ]; then
    image_tag="$CUSTOM_TAG"
  else
    image_tag="$(get_project_version)"
  fi

  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"

  echo "=========================================================="
  echo "  Deploy Mazebank no Azure Kubernetes Service (AKS)"
  echo "=========================================================="
  echo "Ambiente:          $target_env (arquivo: $env_file)"
  echo "Resource Group:    $AZ_RESOURCE_GROUP"
  echo "Cluster AKS:       $AZ_CLUSTER_NAME"
  echo "Tag da Imagem:     $image_tag"
  echo "Log:               $LOG_FILE"
  echo "=========================================================="

  log "Inicio do deploy no Azure AKS"
  log "Resource Group: $AZ_RESOURCE_GROUP | Cluster: $AZ_CLUSTER_NAME | Tag: $image_tag"

  echo "[1/7] Verificando pre-requisitos (az, kubectl, helm)..."
  check_prereqs

  echo "[2/7] Validando conexao, assinatura e provedores no Azure..."
  check_azure_auth
  check_resource_providers

  echo "[3/7] Conectando kubectl ao cluster AKS..."
  log "Obtendo credenciais do AKS..."
  if ! az aks get-credentials -g "$AZ_RESOURCE_GROUP" -n "$AZ_CLUSTER_NAME" --overwrite-existing >>"$LOG_FILE" 2>&1; then
    fail "Falha ao obter credenciais do cluster AKS '$AZ_CLUSTER_NAME' no Resource Group '$AZ_RESOURCE_GROUP'."
  fi
  echo "✔ Contexto kubectl configurado com sucesso para '$AZ_CLUSTER_NAME'."

  echo "[4/7] Configurando Azure Container Registry (ACR)..."
  AZ_ACR_NAME="$(resolve_acr "$AZ_RESOURCE_GROUP" "$AZ_ACR_NAME")"
  ensure_acr "$AZ_RESOURCE_GROUP" "$AZ_ACR_NAME" "$AZ_LOCATION" "$AZ_CLUSTER_NAME"

  if [ "$SKIP_BUILD" -eq 0 ]; then
    echo "[5/7] Gerando imagem do container e enviando para o ACR..."
    build_and_push_image "$AZ_ACR_NAME" "$image_tag"
  else
    echo "[5/7] Build ignorado (--skip-build especificado)."
  fi

  echo "[6/7] Aplicando aplicacao via Helm Chart..."
  local values_file="$ROOT_DIR/helm/mazebank/values-azure.yaml"
  if [ ! -f "$values_file" ]; then
    values_file="$ROOT_DIR/helm/mazebank/values.yaml"
  fi

  local image_repo="${AZ_ACR_NAME}.azurecr.io/mazebank"
  log "Aplicando helm upgrade --install..."
  if ! helm upgrade --install "$APP_RELEASE" "$ROOT_DIR/helm/mazebank" \
    --namespace "$APP_NAMESPACE" \
    --create-namespace \
    -f "$values_file" \
    --set image.repository="$image_repo" \
    --set image.tag="$image_tag" >>"$LOG_FILE" 2>&1; then
    fail "Falha ao aplicar o Helm chart no AKS."
  fi
  echo "✔ Helm release '$APP_RELEASE' aplicada."

  echo "Injetando variaveis de ambiente de $env_file no ConfigMap..."
  log "Criando/atualizando ConfigMap mazebank-config..."
  if ! kubectl create configmap mazebank-config \
    --namespace "$APP_NAMESPACE" \
    --from-env-file="$env_file" \
    --dry-run=client -o yaml | kubectl apply -f - >>"$LOG_FILE" 2>&1; then
    fail "Falha ao injetar variaveis de ambiente no ConfigMap."
  fi

  log "Reiniciando deployment para aplicar nova versao/configuracoes..."
  kubectl rollout restart "deployment/$APP_RELEASE" -n "$APP_NAMESPACE" >>"$LOG_FILE" 2>&1

  echo "[7/7] Aguardando a aplicacao ficar pronta no cluster..."
  log "Aguardando rollout da aplicacao..."
  if ! kubectl rollout status "deployment/$APP_RELEASE" -n "$APP_NAMESPACE" --timeout=300s >>"$LOG_FILE" 2>&1; then
    kubectl get pods -n "$APP_NAMESPACE" -o wide >>"$LOG_FILE" 2>&1 || true
    kubectl describe deployment "$APP_RELEASE" -n "$APP_NAMESPACE" >>"$LOG_FILE" 2>&1 || true
    kubectl logs -n "$APP_NAMESPACE" "deploy/$APP_RELEASE" --tail=50 >>"$LOG_FILE" 2>&1 || true
    fail "Aplicacao nao ficou pronta dentro do tempo limite (300s)."
  fi
  echo "✔ Pods da aplicacao estao em execucao e saudaveis!"

  echo
  echo "Obtendo IP publico / status de exposicao..."
  local external_ip=""
  local attempt=0
  local max_attempts=15

  while [ -z "$external_ip" ] || [ "$external_ip" = "<pending>" ]; do
    attempt=$((attempt + 1))
    external_ip=$(kubectl get ingress "$APP_RELEASE" -n "$APP_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    if [ -z "$external_ip" ]; then
      external_ip=$(kubectl get svc -n nginx nginx-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    fi
    if [ -z "$external_ip" ]; then
      external_ip=$(kubectl get svc "$APP_RELEASE" -n "$APP_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    fi
    if [ -n "$external_ip" ] && [ "$external_ip" != "<pending>" ]; then
      break
    fi
    if [ "$attempt" -gt "$max_attempts" ]; then
      break
    fi
    sleep 3
  done

  echo
  echo "=========================================================="
  echo "  ✅ DEPLOY CONCLUIDO COM SUCESSO NO AZURE AKS!"
  echo "=========================================================="
  local fqdn="mazebank-app.${AZ_LOCATION}.cloudapp.azure.com"
  local proto="http"
  if kubectl get ingress "$APP_RELEASE" -n "$APP_NAMESPACE" -o jsonpath='{.spec.tls}' 2>/dev/null | grep -q "secretName"; then
    proto="https"
  fi

  if [ -n "$external_ip" ]; then
    echo "IP Publico:       $external_ip"
    echo "Dominio Publico:  ${proto}://${fqdn}/mazebank"
    echo "Healthcheck URL:  ${proto}://${fqdn}/mazebank/actuator/health"
    echo
    echo "Testando endpoint de saude via Dominio Azure:"
    curl -s -k --connect-timeout 5 "${proto}://${fqdn}/mazebank/actuator/health" || echo "(Aguarde alguns instantes para propagacao DNS/TLS)"
    echo
  else
    echo "Dominio Publico:  ${proto}://${fqdn}/mazebank"
    echo "Healthcheck URL:  ${proto}://${fqdn}/mazebank/actuator/health"
  fi
  echo "=========================================================="
  echo "Comandos uteis:"
  echo "  kubectl get pods -n $APP_NAMESPACE"
  echo "  kubectl get svc -n $APP_NAMESPACE"
  echo "  $0 logs       (Acompanha os logs em tempo real)"
  echo "  $0 status     (Verifica a saude dos recursos)"
  echo "=========================================================="
}

cmd_status() {
  check_prereqs
  log "Consultando status no namespace $APP_NAMESPACE..."
  echo "=== Pods ==="
  kubectl get pods -n "$APP_NAMESPACE" -o wide
  echo
  echo "=== Services ==="
  kubectl get svc -n "$APP_NAMESPACE"
  echo
  echo "=== Ingress ==="
  kubectl get ingress -n "$APP_NAMESPACE"
  echo
  echo "=== Certificados TLS ==="
  kubectl get certificate -n "$APP_NAMESPACE" 2>/dev/null || true
  echo
  echo "=== Eventos recentes ==="
  kubectl get events -n "$APP_NAMESPACE" --sort-by='.lastTimestamp' | tail -n 10
}

cmd_logs() {
  check_prereqs
  kubectl logs -n "$APP_NAMESPACE" "deploy/$APP_RELEASE" -f --tail=100
}

cmd_destroy() {
  check_prereqs
  echo "Removendo release Helm '$APP_RELEASE' no namespace '$APP_NAMESPACE'..."
  helm uninstall "$APP_RELEASE" -n "$APP_NAMESPACE" || true
  echo "Removendo namespace '$APP_NAMESPACE'..."
  kubectl delete namespace "$APP_NAMESPACE" || true
  echo "✔ Recursos removidos do cluster AKS."
}

# ---------------------------------------------------------------------------
# Entrada e processamento de argumentos
# ---------------------------------------------------------------------------
COMMAND="deploy"
TARGET_ENV="$DEFAULT_ENV"

while [ $# -gt 0 ]; do
  case "$1" in
    deploy|status|logs|destroy|help)
      COMMAND="$1"
      shift
      ;;
    real|local)
      TARGET_ENV="$1"
      shift
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --local-docker)
      USE_LOCAL_DOCKER=1
      shift
      ;;
    --acr)
      AZ_ACR_NAME="$2"
      shift 2
      ;;
    --rg)
      AZ_RESOURCE_GROUP="$2"
      shift 2
      ;;
    --cluster)
      AZ_CLUSTER_NAME="$2"
      shift 2
      ;;
    --tag)
      CUSTOM_TAG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Argumento desconhecido: $1"
      usage
      exit 1
      ;;
  esac
done

case "$COMMAND" in
  deploy)
    cmd_deploy "$TARGET_ENV"
    ;;
  status)
    cmd_status
    ;;
  logs)
    cmd_logs
    ;;
  destroy)
    cmd_destroy
    ;;
  help)
    usage
    ;;
esac
