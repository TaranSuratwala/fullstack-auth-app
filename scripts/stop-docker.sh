#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker CLI not found. Install Docker Desktop (or Docker Engine + Compose) and retry." >&2
  exit 1
fi

if [[ "${1:-}" == "--volumes" ]]; then
  docker compose down -v
else
  docker compose down
fi

echo "AuthVault containers stopped successfully."
