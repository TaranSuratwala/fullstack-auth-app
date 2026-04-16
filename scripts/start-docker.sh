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

for arg in "$@"; do
  case "$arg" in
    --build)
      REBUILD=true
      ;;
    --check-health)
      CHECK_HEALTH=true
      ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Supported options: --build --check-health" >&2
      exit 1
      ;;
  esac
done

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
echo "  App:    http://localhost:8080"
echo "  Health: http://localhost:8080/api/health"

if [[ "$CHECK_HEALTH" == "true" ]]; then
  "$SCRIPT_DIR/check-docker-health.sh"
fi
