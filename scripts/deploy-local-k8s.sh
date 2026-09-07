#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

# Se o Docker Linux nativo nao estiver respondendo, mas docker.exe (Windows) estiver disponivel via WSL,
# configura automaticamente o wrapper para permitir a integracao transparente com o Docker Desktop.
if ! docker info >/dev/null 2>&1 && command -v docker.exe >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/bin"
  cat <<'EOF_DOCKER' > "$HOME/.local/bin/docker"
#!/usr/bin/env bash
exec docker.exe "$@"
EOF_DOCKER
  chmod +x "$HOME/.local/bin/docker"
  export PATH="$HOME/.local/bin:$PATH"
fi

# Ponto de entrada unico do ambiente local em Kind.
#   deploy  Sobe/reutiliza o cluster, gera a imagem, aplica o chart e injeta o ConfigMap.
#   debug   Publica o Mongo e PingDirectory do cluster em localhost para rodar a app no IntelliJ/Maven.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAMESPACE="mazebank"
APP_RELEASE="mazebank"
APP_IMAGE="mazebank:local"
APP_HOST="mazebank.local"
HEALTH_URL="http://${APP_HOST}/mazebank/actuator/health"

# O values-local.yaml aponta a app para o Mongo externo no namespace 'mongodb'
# (mongodb.enabled: false), entao o port-forward de debug usa esse mesmo service.
MONGO_NAMESPACE="mongodb"
MONGO_SVC="mazebank-cluster-svc"
MONGO_PORT="27017"
MONGO_LOCAL_PORT="${MONGO_LOCAL_PORT:-27017}"
APP_LOCAL_PORT="${APP_LOCAL_PORT:-8080}"
MONGO_URL="mongodb://mazebank-user:mazebank@127.0.0.1:${MONGO_LOCAL_PORT}/mazebank?authSource=admin"

# Configuracoes PingDirectory (LDAP)
LDAP_NAMESPACE="pingidentity"
LDAP_SVC="pingdirectory-pingdirectory"
LDAP_PORT="389"
LDAP_LOCAL_PORT="${LDAP_LOCAL_PORT:-389}"
LDAP_URL="ldap://127.0.0.1:${LDAP_LOCAL_PORT}"
LDAP_BASE="dc=example,dc=com"
LDAP_USER_DN="cn=administrator"
LDAP_PASSWORD="2FederateM0re"

PID_FILE="${TMPDIR:-/tmp}/mazebank-mongo-port-forward.pid"
PF_LOG="${TMPDIR:-/tmp}/mazebank-mongo-port-forward.log"

LDAP_PID_FILE="${TMPDIR:-/tmp}/mazebank-ldap-port-forward.pid"
LDAP_PF_LOG="${TMPDIR:-/tmp}/mazebank-ldap-port-forward.log"

LOG_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOG_DIR/local-k8s-deploy.log"

usage() {
  cat <<EOF
Uso: $0 [comando] [opcoes]

Comandos:
  deploy [local|real] [--debug]   Deploy completo no Kind (padrao)
  debug <start|stop|status>       Port-forward do Mongo (${MONGO_NAMESPACE}) e PingDirectory (${LDAP_NAMESPACE}) para localhost
  help                            Esta ajuda

Compatibilidade (invocacao antiga):
  $0          = $0 deploy local
  $0 local    = $0 deploy local
  $0 real     = $0 deploy real

Variaveis opcionais:
  MONGO_LOCAL_PORT  (default: 27017)
  LDAP_LOCAL_PORT   (default: 389)
  APP_LOCAL_PORT    (default: 8080) - so informativo

No IntelliJ, apos 'debug start', use as variaveis:

  PORT=${APP_LOCAL_PORT}
  SPRING_PROFILES_ACTIVE=local
  MONGO_CONNECTION_URL=${MONGO_URL}
  LDAP_URL=${LDAP_URL}
  LDAP_BASE=${LDAP_BASE}
  LDAP_USER_DN=${LDAP_USER_DN}
  LDAP_PASSWORD=${LDAP_PASSWORD}
EOF
}

log() {
  mkdir -p "$LOG_DIR"
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

require_kubectl() {
  if ! kubectl version --client >/dev/null 2>&1; then
    echo "kubectl nao encontrado."
    exit 1
  fi
}

is_wsl() {
  grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null
}

resolve_cluster_name() {
  local existing
  existing=$(kind get clusters 2>/dev/null | head -n 1 || true)
  if [ -n "$existing" ]; then
    echo "$existing"
  else
    echo "mazebank"
  fi
}

update_hosts() {
  local hosts_file="/etc/hosts"
  local entry="127.0.0.1 ${APP_HOST}"

  if grep -qE '^[[:space:]]*127\.0\.0\.1[[:space:]]+mazebank\\.local([[:space:]]|$)' "$hosts_file" 2>/dev/null; then
    return 0
  fi

  if [[ -w "$hosts_file" ]]; then
    echo "$entry" >>"$hosts_file"
    return 0
  fi

  if command -v sudo >/dev/null 2>&1; then
    echo "$entry" | sudo -n tee -a "$hosts_file" >/dev/null 2>&1 || true
    if grep -qE '^[[:space:]]*127\.0\.0\.1[[:space:]]+mazebank\\.local([[:space:]]|$)' "$hosts_file" 2>/dev/null; then
      return 0
    fi
  fi

  return 1
}

# ---------------------------------------------------------------------------
# deploy
# ---------------------------------------------------------------------------

cmd_deploy() {
  local target_env="$1"
  local with_debug="$2"

  local env_file="$ROOT_DIR/ENV/$target_env/env.conf"
  if [ ! -f "$env_file" ]; then
    echo "Erro: Arquivo de ambiente nao encontrado: $env_file"
    exit 1
  fi

  local cluster_name
  cluster_name="$(resolve_cluster_name)"

  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"

  log "Inicio do deploy local Kubernetes (Ambiente: $target_env)"
  log "Cluster: $cluster_name"
  log "Variaveis de ambiente lidas de: $env_file"

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
  if kind get clusters 2>/dev/null | grep -qx "$cluster_name"; then
    echo "Cluster $cluster_name ja existe."
    log "Cluster $cluster_name ja existe"
  else
    # Verifica se existe config do kind, senao cria cluster simples
    if [ -f "helm/kind-config.yaml" ]; then
      if ! kind create cluster --name "$cluster_name" --config helm/kind-config.yaml >>"$LOG_FILE" 2>&1; then
        fail "Falha ao criar o cluster kind com o arquivo de configuracao"
      fi
    else
      if ! kind create cluster --name "$cluster_name" >>"$LOG_FILE" 2>&1; then
        fail "Falha ao criar o cluster kind"
      fi
    fi
  fi

  if ! kubectl config use-context "kind-$cluster_name" >>"$LOG_FILE" 2>&1; then
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
  if ! docker build -t "$APP_IMAGE" . >>"$LOG_FILE" 2>&1; then
    fail "Falha ao gerar a imagem Docker"
  fi

  echo "[8/11] Carregando imagem no cluster kind..."
  log "Carregando imagem no cluster kind"
  if ! kind load docker-image "$APP_IMAGE" --name "$cluster_name" >>"$LOG_FILE" 2>&1; then
    log "Falha no kind load. Tentando carregar imagem via docker exec (fallback)..."
    if ! docker save "$APP_IMAGE" | docker exec -i "${cluster_name}-control-plane" ctr -n k8s.io images import - >>"$LOG_FILE" 2>&1; then
      fail "Falha ao carregar a imagem no cluster kind (mesmo via fallback)"
    fi
  fi

  echo "[9/11] Aplicando Helm Chart local..."
  log "Aplicando Helm Chart local"
  if ! helm upgrade --install "$APP_RELEASE" ./helm/mazebank -n "$APP_NAMESPACE" --create-namespace -f ./helm/mazebank/values-local.yaml >>"$LOG_FILE" 2>&1; then
    fail "Falha ao aplicar o Helm Chart"
  fi

  echo "[10/11] Injetando variaveis dinamicas de ambiente ($target_env)..."
  log "Criando/atualizando ConfigMap a partir do arquivo $env_file"
  if ! kubectl create configmap mazebank-config --namespace "$APP_NAMESPACE" --from-env-file="$env_file" --dry-run=client -o yaml | kubectl apply -f - >>"$LOG_FILE" 2>&1; then
    fail "Falha ao injetar variaveis de ambiente do $env_file no ConfigMap"
  fi

  log "Forcando rollout da aplicacao"
  if ! kubectl rollout restart "deployment/$APP_RELEASE" -n "$APP_NAMESPACE" >>"$LOG_FILE" 2>&1; then
    fail "Falha ao reiniciar o deployment da aplicacao"
  fi

  echo "[11/11] Aguardando a aplicacao ficar pronta..."
  log "Aguardando rollout do Mongo (se houver)"
  if kubectl get deployment mongo -n "$APP_NAMESPACE" >/dev/null 2>&1; then
    if ! kubectl rollout status deployment/mongo -n "$APP_NAMESPACE" --timeout=180s >>"$LOG_FILE" 2>&1; then
      kubectl get pods -n "$APP_NAMESPACE" -o wide >>"$LOG_FILE" 2>&1 || true
      kubectl describe deployment mongo -n "$APP_NAMESPACE" >>"$LOG_FILE" 2>&1 || true
      kubectl logs -n "$APP_NAMESPACE" deploy/mongo >>"$LOG_FILE" 2>&1 || true
      fail "Mongo nao ficou pronto"
    fi
  fi

  log "Aguardando rollout da aplicacao"
  if ! kubectl rollout status "deployment/$APP_RELEASE" -n "$APP_NAMESPACE" --timeout=180s >>"$LOG_FILE" 2>&1; then
    kubectl get pods -n "$APP_NAMESPACE" -o wide >>"$LOG_FILE" 2>&1 || true
    kubectl describe deployment "$APP_RELEASE" -n "$APP_NAMESPACE" >>"$LOG_FILE" 2>&1 || true
    kubectl logs -n "$APP_NAMESPACE" "deploy/$APP_RELEASE" >>"$LOG_FILE" 2>&1 || true
    fail "Aplicacao nao ficou pronta"
  fi

  if is_wsl; then
    # O /etc/hosts do WSL nao resolve nomes para o navegador do Windows;
    # quem cuida do hosts do Windows e o wrapper scripts/deploy-local-k8s.bat.
    log "Execucao sob WSL: hosts do Windows fica a cargo de scripts/deploy-local-k8s.bat"
  else
    echo "Atualizando hosts local para ${APP_HOST}..."
    log "Atualizando arquivo hosts"
    if ! update_hosts >>"$LOG_FILE" 2>&1; then
      echo "Nao foi possivel atualizar o arquivo hosts automaticamente."
      echo "Adicione manualmente esta linha em /etc/hosts:"
      echo "127.0.0.1 ${APP_HOST}"
      log "Falha ao atualizar o arquivo hosts automaticamente"
    fi
  fi

  echo
  echo "✅ Cluster local pronto! (Usando configuracoes: $target_env)"
  echo "URL da aplicacao: $HEALTH_URL"
  echo "Log de execucao: $LOG_FILE"
  log "Deploy concluido com sucesso"
  echo
  echo "Comandos uteis:"
  echo "  kubectl get pods -n $APP_NAMESPACE"
  echo "  kubectl get ingress -n $APP_NAMESPACE"
  echo "  kubectl logs -n $APP_NAMESPACE deploy/$APP_RELEASE"
  echo "  $0 debug start   # Mongo e PingDirectory do cluster em localhost para o IntelliJ"
  echo "  kind delete cluster --name $cluster_name"

  if [ "$with_debug" = "1" ]; then
    echo
    debug_start
  fi
}

# ---------------------------------------------------------------------------
# debug
# ---------------------------------------------------------------------------

stop_port_forward() {
  # Mongo
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "${pid}" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
  fi
  pkill -f "port-forward .*svc/${MONGO_SVC} ${MONGO_LOCAL_PORT}:${MONGO_PORT}" 2>/dev/null || true

  # PingDirectory (LDAP)
  if [[ -f "$LDAP_PID_FILE" ]]; then
    local ldap_pid
    ldap_pid="$(cat "$LDAP_PID_FILE" 2>/dev/null || true)"
    if [[ -n "${ldap_pid}" ]] && kill -0 "$ldap_pid" 2>/dev/null; then
      kill "$ldap_pid" 2>/dev/null || true
      wait "$ldap_pid" 2>/dev/null || true
    fi
    rm -f "$LDAP_PID_FILE"
  fi
  pkill -f "port-forward .*svc/${LDAP_SVC} ${LDAP_LOCAL_PORT}:${LDAP_PORT}" 2>/dev/null || true
}

debug_start() {
  require_kubectl

  stop_port_forward

  # 1. Port forward MongoDB
  if kubectl get ns "$MONGO_NAMESPACE" >/dev/null 2>&1; then
    echo "Publicando Mongo do Kind (${MONGO_NAMESPACE}) em 127.0.0.1:${MONGO_LOCAL_PORT}..."
    nohup kubectl -n "$MONGO_NAMESPACE" port-forward --address 127.0.0.1 \
      "svc/${MONGO_SVC}" "${MONGO_LOCAL_PORT}:${MONGO_PORT}" >"$PF_LOG" 2>&1 &
    echo $! >"$PID_FILE"
    disown || true
    sleep 1

    if ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      rm -f "$PID_FILE"
      echo "Falha ao iniciar port-forward do Mongo. Porta ${MONGO_LOCAL_PORT} pode estar em uso."
      echo "Saida do kubectl:"
      cat "$PF_LOG" 2>/dev/null || true
    fi
  else
    echo "Aviso: Namespace ${MONGO_NAMESPACE} nao encontrado. Pulando port-forward do Mongo."
  fi

  # 2. Port forward PingDirectory
  if kubectl get ns "$LDAP_NAMESPACE" >/dev/null 2>&1; then
    echo "Publicando PingDirectory LDAP (${LDAP_NAMESPACE}) em 127.0.0.1:${LDAP_LOCAL_PORT}..."
    nohup kubectl -n "$LDAP_NAMESPACE" port-forward --address 127.0.0.1 \
      "svc/${LDAP_SVC}" "${LDAP_LOCAL_PORT}:${LDAP_PORT}" >"$LDAP_PF_LOG" 2>&1 &
    echo $! >"$LDAP_PID_FILE"
    disown || true
    sleep 1

    if ! kill -0 "$(cat "$LDAP_PID_FILE")" 2>/dev/null; then
      rm -f "$LDAP_PID_FILE"
      echo "Falha ao iniciar port-forward do PingDirectory. Porta ${LDAP_LOCAL_PORT} pode estar em uso."
      echo "Saida do kubectl:"
      cat "$LDAP_PF_LOG" 2>/dev/null || true
    fi
  else
    echo "Aviso: Namespace ${LDAP_NAMESPACE} nao encontrado. Pulando port-forward do PingDirectory."
  fi

  cat <<EOF

Servicos locais prontos para debug:
  Mongo:          ${MONGO_URL}
  PingDirectory:  ${LDAP_URL} (Base: ${LDAP_BASE})
  App no Kind:    ${HEALTH_URL}

No IntelliJ, use as variaveis:

  PORT=${APP_LOCAL_PORT}
  SPRING_PROFILES_ACTIVE=local
  MONGO_CONNECTION_URL=${MONGO_URL}
  LDAP_URL=${LDAP_URL}
  LDAP_BASE=${LDAP_BASE}
  LDAP_USER_DN=${LDAP_USER_DN}
  LDAP_PASSWORD=${LDAP_PASSWORD}

Quando terminar:
  $0 debug stop
EOF
}

debug_stop() {
  echo "Encerrando port-forward do Mongo e PingDirectory..."
  stop_port_forward
  echo "Port-forward encerrado. App no Kind permanece: ${HEALTH_URL}"
}

debug_status() {
  require_kubectl
  echo "=== port-forward Mongo ==="
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "ativo (pid=$(cat "$PID_FILE")) -> 127.0.0.1:${MONGO_LOCAL_PORT}"
  else
    echo "inativo"
  fi
  echo
  echo "=== port-forward PingDirectory (LDAP) ==="
  if [[ -f "$LDAP_PID_FILE" ]] && kill -0 "$(cat "$LDAP_PID_FILE")" 2>/dev/null; then
    echo "ativo (pid=$(cat "$LDAP_PID_FILE")) -> 127.0.0.1:${LDAP_LOCAL_PORT}"
  else
    echo "inativo"
  fi
  echo
  echo "=== pods (${MONGO_NAMESPACE}) ==="
  kubectl get pods -n "$MONGO_NAMESPACE" -o wide 2>/dev/null || echo "namespace ausente"
  echo
  echo "=== pods (${LDAP_NAMESPACE}) ==="
  kubectl get pods -n "$LDAP_NAMESPACE" -o wide 2>/dev/null || echo "namespace ausente"
}

# ---------------------------------------------------------------------------
# dispatch
# ---------------------------------------------------------------------------

dispatch_deploy() {
  local target_env="local"
  local with_debug=0

  while [ $# -gt 0 ]; do
    case "$1" in
      local|real) target_env="$1" ;;
      --debug) with_debug=1 ;;
      *)
        echo "Erro: argumento invalido para deploy: $1"
        echo
        usage
        exit 1
        ;;
    esac
    shift
  done

  cmd_deploy "$target_env" "$with_debug"
}

dispatch_debug() {
  case "${1:-}" in
    start) debug_start ;;
    stop) debug_stop ;;
    status) debug_status ;;
    *)
      echo "Erro: use 'debug start', 'debug stop' ou 'debug status'."
      echo
      usage
      exit 1
      ;;
  esac
}

case "${1:-}" in
  ""|local|real)
    dispatch_deploy "$@"
    ;;
  deploy)
    shift
    dispatch_deploy "$@"
    ;;
  debug)
    shift
    dispatch_debug "${1:-}"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Erro: comando invalido: $1"
    echo
    usage
    exit 1
    ;;
esac
