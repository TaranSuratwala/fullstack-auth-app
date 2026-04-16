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

## 3) Build and run

### Option A: One-command helper scripts (recommended)

Windows PowerShell:

```powershell
./scripts/start-docker.ps1 -Rebuild -CheckHealth
```

Windows double-click:

- Run `start-docker.cmd`

Linux/macOS:

```bash
chmod +x scripts/*.sh
./scripts/start-docker.sh --build --check-health
```

### Option B: Docker Compose directly

```bash
docker compose up --build -d
```

## 4) Access the app

- App: http://localhost:8080
- Health endpoint: http://localhost:8080/api/health

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

If you want Google OAuth to work in your colleague environments, add the local origin in Google Cloud OAuth settings:

- `http://localhost:8080`

And set `GOOGLE_CLIENT_ID` in `.env`.
