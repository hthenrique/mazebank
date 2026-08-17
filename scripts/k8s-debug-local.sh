#!/usr/bin/env bash
set -euo pipefail

# Publica o Mongo do Kind (namespace mongodb) em localhost para debug no IntelliJ/Maven.
# Mantem a app no cluster rodando (Ingress em mazebank.local).

NAMESPACE="mongodb"
MONGO_LOCAL_PORT="${MONGO_LOCAL_PORT:-27017}"
APP_LOCAL_PORT="${APP_LOCAL_PORT:-8080}"
PID_FILE="${TMPDIR:-/tmp}/mazebank-mongo-port-forward.pid"

usage() {
  cat <<EOF
Uso: $0 <start|stop|status>

  start   Publica Mongo do Kind (${NAMESPACE}) em localhost:${MONGO_LOCAL_PORT}
  stop    Encerra o port-forward
  status  Mostra estado do port-forward e dos pods

Variaveis opcionais:
  MONGO_LOCAL_PORT  (default: 27017)
  APP_LOCAL_PORT    (default: 8080) — so informativo

IntelliJ: use as variaveis:

  PORT=${APP_LOCAL_PORT}
  SPRING_PROFILES_ACTIVE=local
  MONGO_CONNECTION_URL=mongodb://mazebank-user:mazebank@127.0.0.1:${MONGO_LOCAL_PORT}/mazebank?authSource=admin
EOF
}

require_kubectl() {
  if ! kubectl version --client >/dev/null 2>&1; then
    echo "kubectl nao encontrado."
    exit 1
  fi
}

stop_port_forward() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "${pid}" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
  fi
  pkill -f "port-forward svc/mazebank-cluster-svc ${MONGO_LOCAL_PORT}:27017" 2>/dev/null || true
}

cmd_start() {
  require_kubectl

  if ! kubectl get ns "$NAMESPACE" >/dev/null 2>&1; then
    echo "Namespace ${NAMESPACE} nao encontrado. Rode ./scripts/deploy-local-k8s.sh antes."
    exit 1
  fi

  stop_port_forward

  echo "Publicando Mongo do Kind (${NAMESPACE}) em 127.0.0.1:${MONGO_LOCAL_PORT}..."
  kubectl -n "$NAMESPACE" port-forward svc/mazebank-cluster-svc "${MONGO_LOCAL_PORT}:27017" >/dev/null 2>&1 &
  echo $! >"$PID_FILE"
  sleep 1

  if ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    rm -f "$PID_FILE"
    echo "Falha ao iniciar port-forward do Mongo. Porta ${MONGO_LOCAL_PORT} pode estar em uso."
    exit 1
  fi

  cat <<EOF

Mongo local pronto: mongodb://mazebank-user:mazebank@127.0.0.1:${MONGO_LOCAL_PORT}/mazebank?authSource=admin
App no Kind:        http://mazebank.local/mazebank/actuator/health

No IntelliJ, use as variaveis:

  PORT=${APP_LOCAL_PORT}
  SPRING_PROFILES_ACTIVE=local
  MONGO_CONNECTION_URL=mongodb://mazebank-user:mazebank@127.0.0.1:${MONGO_LOCAL_PORT}/mazebank?authSource=admin

Quando terminar:
  $0 stop
EOF
}

cmd_stop() {
  echo "Encerrando port-forward do Mongo..."
  stop_port_forward
  echo "Port-forward encerrado. App no Kind permanece: http://mazebank.local/mazebank/actuator/health"
}

cmd_status() {
  require_kubectl
  echo "=== port-forward ==="
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "ativo (pid=$(cat "$PID_FILE")) -> 127.0.0.1:${MONGO_LOCAL_PORT}"
  else
    echo "inativo"
  fi
  echo
  echo "=== pods (${NAMESPACE}) ==="
  kubectl get pods -n "$NAMESPACE" -o wide 2>/dev/null || echo "namespace ausente"
}

case "${1:-}" in
  start) cmd_start ;;
  stop) cmd_stop ;;
  status) cmd_status ;;
  *) usage; exit 1 ;;
esac
