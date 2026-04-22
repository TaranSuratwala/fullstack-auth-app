#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker CLI not found. Install Docker Desktop (or Docker Engine + Compose) and retry." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker engine is not running. Start Docker Desktop and retry." >&2
  exit 1
fi

REBUILD=false
CHECK_HEALTH=false
PORT_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build)
      REBUILD=true
      shift
      ;;
    --check-health)
      CHECK_HEALTH=true
      shift
      ;;
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
      echo "Supported options: --build --check-health --port <host-port>" >&2
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

if [[ ! -f .env ]]; then
  if [[ ! -f docker.env.example ]]; then
    echo "Missing docker.env.example. Cannot auto-create .env file." >&2
    exit 1
  fi
  cp docker.env.example .env
  echo "Created .env from docker.env.example. Update JWT_SECRET before sharing."
fi

if [[ "$REBUILD" == "true" ]]; then
  docker compose up --build -d
else
  docker compose up -d
fi

echo ""
echo "AuthVault is running:"
echo "  App:    http://localhost:${APP_PORT_EFFECTIVE}"
echo "  Health: http://localhost:${APP_PORT_EFFECTIVE}/api/health"

if [[ "$CHECK_HEALTH" == "true" ]]; then
  if [[ -n "$PORT_ARG" ]]; then
    "$SCRIPT_DIR/check-docker-health.sh" --port "$PORT_ARG"
  else
    "$SCRIPT_DIR/check-docker-health.sh"
  fi
fi
