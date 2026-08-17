#!/usr/bin/env bash
set -euo pipefail

# Configuração de Ambiente
TARGET_ENV=${1:-local}

if [ "$TARGET_ENV" != "local" ] && [ "$TARGET_ENV" != "real" ]; then
  echo "Erro: Ambiente inválido. Escolha 'local' ou 'real'."
  exit 1
fi

# ROOT_DIR agora aponta para a raiz do projeto (uma pasta acima de scripts/)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ENV_FILE="$ROOT_DIR/ENV/$TARGET_ENV/env.conf"

if [ ! -f "$ENV_FILE" ]; then
  echo "Erro: Arquivo de ambiente não encontrado: $ENV_FILE"
  exit 1
fi

EXISTING_CLUSTER=$(kind get clusters 2>/dev/null | head -n 1)
if [ -n "$EXISTING_CLUSTER" ]; then
  CLUSTER_NAME="$EXISTING_CLUSTER"
else
  CLUSTER_NAME="mazebank"
fi
LOG_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOG_DIR/local-k8s-deploy.log"

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

fail() {
  echo
  echo "Erro: $*"
  echo "Analise o arquivo de log em:"
  echo "$LOG_FILE"
  log "ERRO: $*"
  exit 1
}

log "Inicio do deploy local Kubernetes (Ambiente: $TARGET_ENV)"
log "Cluster: $CLUSTER_NAME"
log "Variaveis de ambiente lidas de: $ENV_FILE"

echo "[1/11] Verificando Docker..."
log "Verificando Docker"
if ! docker info >>"$LOG_FILE" 2>&1; then
  fail "Docker nao esta em execucao. Abra o Docker Desktop / daemon e tente novamente."
fi

echo "[2/11] Verificando kind..."
log "Verificando kind"
if ! kind version >>"$LOG_FILE" 2>&1; then
  fail "kind nao encontrado. Instale o kind e tente novamente."
fi

echo "[3/11] Verificando kubectl..."
log "Verificando kubectl"
if ! kubectl version --client >>"$LOG_FILE" 2>&1; then
  fail "kubectl nao encontrado. Instale o kubectl e tente novamente."
fi

log "Verificando helm"
if ! helm version --short >>"$LOG_FILE" 2>&1; then
  fail "helm nao encontrado. Instale o helm e tente novamente."
fi

echo "[4/11] Criando ou reutilizando cluster kind..."
log "Criando ou reutilizando cluster kind"
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "Cluster $CLUSTER_NAME ja existe."
  log "Cluster $CLUSTER_NAME ja existe"
else
  # Verifica se existe config do kind, senao cria cluster simples
  if [ -f "helm/kind-config.yaml" ]; then
    if ! kind create cluster --name "$CLUSTER_NAME" --config helm/kind-config.yaml >>"$LOG_FILE" 2>&1; then
      fail "Falha ao criar o cluster kind com o arquivo de configuracao"
    fi
  else
    if ! kind create cluster --name "$CLUSTER_NAME" >>"$LOG_FILE" 2>&1; then
      fail "Falha ao criar o cluster kind"
    fi
  fi
fi

if ! kubectl config use-context "kind-$CLUSTER_NAME" >>"$LOG_FILE" 2>&1; then
  fail "Falha ao selecionar o contexto do cluster"
fi

echo "[5/11] Instalando ingress-nginx..."
log "Instalando ingress-nginx"
if ! kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml >>"$LOG_FILE" 2>&1; then
  fail "Falha ao instalar o ingress-nginx"
fi

echo "[6/11] Aguardando ingress-nginx ficar pronto..."
log "Aguardando ingress-nginx ficar pronto"
if ! kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s >>"$LOG_FILE" 2>&1; then
  kubectl get pods -n ingress-nginx -o wide >>"$LOG_FILE" 2>&1 || true
  kubectl describe pods -n ingress-nginx >>"$LOG_FILE" 2>&1 || true
  fail "Ingress-nginx nao ficou pronto"
fi

echo "[7/11] Gerando imagem Docker local..."
log "Gerando imagem Docker local"
if ! docker build -t mazebank:local . >>"$LOG_FILE" 2>&1; then
  fail "Falha ao gerar a imagem Docker"
fi

echo "[8/11] Carregando imagem no cluster kind..."
log "Carregando imagem no cluster kind"
if ! kind load docker-image mazebank:local --name "$CLUSTER_NAME" >>"$LOG_FILE" 2>&1; then
  log "Falha no kind load. Tentando carregar imagem via docker exec (fallback)..."
  if ! docker save mazebank:local | docker exec -i "${CLUSTER_NAME}-control-plane" ctr -n k8s.io images import - >>"$LOG_FILE" 2>&1; then
    fail "Falha ao carregar a imagem no cluster kind (mesmo via fallback)"
  fi
fi

echo "[9/11] Aplicando Helm Chart local..."
log "Aplicando Helm Chart local"
if ! helm upgrade --install mazebank ./helm/mazebank -n mazebank --create-namespace -f ./helm/mazebank/values-local.yaml >>"$LOG_FILE" 2>&1; then
  fail "Falha ao aplicar o Helm Chart"
fi

echo "[10/11] Injetando variaveis dinamicas de ambiente ($TARGET_ENV)..."
log "Criando/atualizando ConfigMap a partir do arquivo $ENV_FILE"
if ! kubectl create configmap mazebank-config --namespace mazebank --from-env-file="$ENV_FILE" --dry-run=client -o yaml | kubectl apply -f - >>"$LOG_FILE" 2>&1; then
  fail "Falha ao injetar variaveis de ambiente do $ENV_FILE no ConfigMap"
fi

log "Forcando rollout da aplicacao"
if ! kubectl rollout restart deployment/mazebank -n mazebank >>"$LOG_FILE" 2>&1; then
  fail "Falha ao reiniciar o deployment da aplicacao"
fi

echo "[11/11] Aguardando a aplicacao ficar pronta..."
log "Aguardando rollout do Mongo (se houver)"
if kubectl get deployment mongo -n mazebank >/dev/null 2>&1; then
  if ! kubectl rollout status deployment/mongo -n mazebank --timeout=180s >>"$LOG_FILE" 2>&1; then
    kubectl get pods -n mazebank -o wide >>"$LOG_FILE" 2>&1 || true
    kubectl describe deployment mongo -n mazebank >>"$LOG_FILE" 2>&1 || true
    kubectl logs -n mazebank deploy/mongo >>"$LOG_FILE" 2>&1 || true
    fail "Mongo nao ficou pronto"
  fi
fi

log "Aguardando rollout da aplicacao"
if ! kubectl rollout status deployment/mazebank -n mazebank --timeout=180s >>"$LOG_FILE" 2>&1; then
  kubectl get pods -n mazebank -o wide >>"$LOG_FILE" 2>&1 || true
  kubectl describe deployment mazebank -n mazebank >>"$LOG_FILE" 2>&1 || true
  kubectl logs -n mazebank deploy/mazebank >>"$LOG_FILE" 2>&1 || true
  fail "Aplicacao nao ficou pronta"
fi

update_hosts() {
  local hosts_file="/etc/hosts"
  local entry="127.0.0.1 mazebank.local"

  if grep -qE '^[[:space:]]*127\.0\.0\.1[[:space:]]+mazebank\.local([[:space:]]|$)' "$hosts_file" 2>/dev/null; then
    return 0
  fi

  if [[ -w "$hosts_file" ]]; then
    echo "$entry" >>"$hosts_file"
    return 0
  fi

  if command -v sudo >/dev/null 2>&1; then
    echo "$entry" | sudo tee -a "$hosts_file" >/dev/null
    return 0
  fi

  return 1
}

echo "Atualizando hosts local para mazebank.local..."
log "Atualizando arquivo hosts"
if ! update_hosts >>"$LOG_FILE" 2>&1; then
  echo "Nao foi possivel atualizar o arquivo hosts automaticamente."
  echo "Adicione manualmente esta linha em /etc/hosts:"
  echo "127.0.0.1 mazebank.local"
  log "Falha ao atualizar o arquivo hosts automaticamente"
fi

echo
echo "✅ Cluster local pronto! (Usando configuracoes: $TARGET_ENV)"
echo "URL da aplicacao: http://mazebank.local/mazebank/actuator/health"
echo "Log de execucao: $LOG_FILE"
log "Deploy concluido com sucesso"
echo
echo "Comandos uteis:"
echo "  kubectl get pods -n mazebank"
echo "  kubectl get ingress -n mazebank"
echo "  kubectl logs -n mazebank deploy/mazebank"
echo "  ./scripts/k8s-debug-local.sh start   # Mongo no host + IntelliJ (.env.local.example)"
echo "  kind delete cluster --name $CLUSTER_NAME"
