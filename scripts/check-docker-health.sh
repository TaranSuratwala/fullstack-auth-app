#!/usr/bin/env bash
set -euo pipefail

TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-90}"
POLL_SECONDS="${POLL_SECONDS:-3}"
PORT_ARG=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --port" >&2
        exit 1
      fi
      PORT_ARG="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Supported options: --port <host-port>" >&2
      exit 1
      ;;
  esac
done

if [[ -n "$PORT_ARG" ]]; then
  export APP_PORT="$PORT_ARG"
fi

resolve_app_port() {
  if [[ -n "${APP_PORT:-}" ]]; then
    echo "$APP_PORT"
    return
  fi

  if [[ -f .env ]]; then
    local env_value
    env_value="$(grep -E '^[[:space:]]*APP_PORT=' .env | tail -n 1 | cut -d '=' -f 2- | tr -d '\r')"
    if [[ -n "$env_value" ]]; then
      echo "$env_value"
      return
    fi
  fi

  echo "8080"
}

APP_PORT_EFFECTIVE="$(resolve_app_port)"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker CLI not found. Install Docker Desktop (or Docker Engine + Compose) and retry." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker engine is not running. Start Docker Desktop and retry." >&2
  exit 1
fi

wait_until() {
  local description="$1"
  local command="$2"
  local elapsed=0

  while (( elapsed < TIMEOUT_SECONDS )); do
    if eval "$command" >/dev/null 2>&1; then
      echo "OK: ${description}"
      return 0
    fi
    sleep "$POLL_SECONDS"
    elapsed=$((elapsed + POLL_SECONDS))
  done

  echo "Timed out waiting for: ${description}" >&2
  return 1
}

wait_until \
  "authvault-db container running" \
  "[[ \"\$(docker inspect -f '{{.State.Running}}' authvault-db 2>/dev/null)\" == \"true\" ]]"

wait_until \
  "authvault-app container running" \
  "[[ \"\$(docker inspect -f '{{.State.Running}}' authvault-app 2>/dev/null)\" == \"true\" ]]"

wait_until \
  "PostgreSQL health is healthy" \
  "[[ \"\$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' authvault-db 2>/dev/null)\" == \"healthy\" ]]"

wait_until \
  "AuthVault HTTP health endpoint responds" \
  "curl -fsS http://localhost:${APP_PORT_EFFECTIVE}/api/health >/dev/null"

echo ""
echo "Docker stack health check passed."
echo "  App:    http://localhost:${APP_PORT_EFFECTIVE}"
echo "  Health: http://localhost:${APP_PORT_EFFECTIVE}/api/health"
