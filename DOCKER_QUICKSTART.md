# Docker Quickstart for Colleagues

This project already contains a production-style `Dockerfile`.
Use the `docker-compose.yml` in this folder to run the complete app stack:

- AuthVault app container (serves frontend + backend API)
- PostgreSQL database container

## 1) Prerequisites

- Docker Desktop (Windows/Mac) or Docker Engine + Compose (Linux)

## 2) Configure environment

From this folder, copy the template and edit values:

```powershell
Copy-Item docker.env.example .env
```

```bash
cp docker.env.example .env
```

At minimum, set a strong `JWT_SECRET` in `.env`.

To run on different host ports, set these in `.env`:

- `APP_PORT` (default `8080`)
- `APP_PORT_SECOND` (default `8081`)

Example:

```dotenv
APP_PORT=8090
APP_PORT_SECOND=8091
```

## 3) Build and run

### Option A: One-command helper scripts (recommended)

Windows PowerShell:

```powershell
./scripts/start-docker.ps1 -Rebuild -CheckHealth
```

Custom port example (PowerShell):

```powershell
./scripts/start-docker.ps1 -Rebuild -CheckHealth -AppPort 8090
```

Custom two-port example (PowerShell):

```powershell
./scripts/start-docker.ps1 -Rebuild -CheckHealth -AppPort 8090 -AppPortSecond 8091
```

Windows double-click:

- Run `start-docker.cmd`

Linux/macOS:

```bash
chmod +x scripts/*.sh
./scripts/start-docker.sh --build --check-health
```

Custom port example (Linux/macOS):

```bash
./scripts/start-docker.sh --build --check-health --port 8090
```

Custom two-port example (Linux/macOS):

```bash
./scripts/start-docker.sh --build --check-health --port 8090 --port-secondary 8091
```

### Option B: Docker Compose directly

```bash
docker compose up --build -d
```

## 4) Access the app

- App: http://localhost:<APP_PORT>
- Health endpoint: http://localhost:<APP_PORT>/api/health
- App 2: http://localhost:<APP_PORT_SECOND>
- Health endpoint: http://localhost:<APP_PORT_SECOND>/api/health

## 5) Validate stack health

Windows PowerShell:

```powershell
./scripts/check-docker-health.ps1
```

Windows double-click:

- Run `check-docker-health.cmd`

Linux/macOS:

```bash
./scripts/check-docker-health.sh
```

## 6) Stop containers

Using helper scripts:

Windows PowerShell:

```powershell
./scripts/stop-docker.ps1
```

Windows double-click:

- Run `stop-docker.cmd`

Linux/macOS:

```bash
./scripts/stop-docker.sh
```

Compose directly:

```bash
docker compose down
```

To also remove database data volume:

```bash
docker compose down -v
```

PowerShell equivalent:

```powershell
./scripts/stop-docker.ps1 -RemoveVolumes
```

## Notes for Google OAuth

If you want Google OAuth to show as configured and work in local environments:

1. Set `GOOGLE_CLIENT_ID` in `.env`.
2. Add both local origins in Google Cloud OAuth settings, for example:
	- `http://localhost:8080`
	- `http://localhost:8081`
