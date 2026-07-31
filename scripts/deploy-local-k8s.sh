#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

CLUSTER_NAME="mazebank"
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

log "Inicio do deploy local Kubernetes"
log "Cluster: $CLUSTER_NAME"

echo "[1/10] Verificando Docker..."
log "Verificando Docker"
if ! docker info >>"$LOG_FILE" 2>&1; then
  fail "Docker nao esta em execucao. Abra o Docker Desktop / daemon e tente novamente."
fi

echo "[2/10] Verificando kind..."
log "Verificando kind"
if ! kind version >>"$LOG_FILE" 2>&1; then
  fail "kind nao encontrado. Instale o kind e tente novamente."
fi

echo "[3/10] Verificando kubectl..."
log "Verificando kubectl"
if ! kubectl version --client >>"$LOG_FILE" 2>&1; then
  fail "kubectl nao encontrado. Instale o kubectl e tente novamente."
fi

echo "[4/10] Criando ou reutilizando cluster kind..."
log "Criando ou reutilizando cluster kind"
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "Cluster $CLUSTER_NAME ja existe."
  log "Cluster $CLUSTER_NAME ja existe"
else
  if ! kind create cluster --name "$CLUSTER_NAME" --config k8s/local/kind-config.yaml >>"$LOG_FILE" 2>&1; then
    fail "Falha ao criar o cluster kind"
  fi
fi

if ! kubectl config use-context "kind-$CLUSTER_NAME" >>"$LOG_FILE" 2>&1; then
  fail "Falha ao selecionar o contexto do cluster"
fi

echo "[5/10] Instalando ingress-nginx..."
log "Instalando ingress-nginx"
if ! kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml >>"$LOG_FILE" 2>&1; then
  fail "Falha ao instalar o ingress-nginx"
fi

echo "[6/10] Aguardando ingress-nginx ficar pronto..."
log "Aguardando ingress-nginx ficar pronto"
if ! kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s >>"$LOG_FILE" 2>&1; then
  kubectl get pods -n ingress-nginx -o wide >>"$LOG_FILE" 2>&1 || true
  kubectl describe pods -n ingress-nginx >>"$LOG_FILE" 2>&1 || true
  fail "Ingress-nginx nao ficou pronto"
fi

echo "[7/10] Gerando imagem Docker local..."
log "Gerando imagem Docker local"
if ! docker build -t mazebank:local . >>"$LOG_FILE" 2>&1; then
  fail "Falha ao gerar a imagem Docker"
fi

echo "[8/10] Carregando imagem no cluster kind..."
log "Carregando imagem no cluster kind"
if ! kind load docker-image mazebank:local --name "$CLUSTER_NAME" >>"$LOG_FILE" 2>&1; then
  fail "Falha ao carregar a imagem no cluster kind"
fi

echo "[9/10] Aplicando manifests Kubernetes..."
log "Aplicando manifests Kubernetes locais"
if ! kubectl apply -k k8s/overlays/local >>"$LOG_FILE" 2>&1; then
  fail "Falha ao aplicar os manifests Kubernetes"
fi

log "Forcando rollout da aplicacao"
if ! kubectl rollout restart deployment/mazebank -n mazebank >>"$LOG_FILE" 2>&1; then
  fail "Falha ao reiniciar o deployment da aplicacao"
fi

echo "[10/10] Aguardando a aplicacao ficar pronta..."
log "Aguardando rollout do Mongo"
if ! kubectl rollout status deployment/mongo -n mazebank --timeout=180s >>"$LOG_FILE" 2>&1; then
  kubectl get pods -n mazebank -o wide >>"$LOG_FILE" 2>&1 || true
  kubectl describe deployment mongo -n mazebank >>"$LOG_FILE" 2>&1 || true
  kubectl logs -n mazebank deploy/mongo >>"$LOG_FILE" 2>&1 || true
  fail "Mongo nao ficou pronto"
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
echo "Cluster local pronto."
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
