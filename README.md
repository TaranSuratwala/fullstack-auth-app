# Fullstack Auth App (AuthVault)

Full-stack authentication app with a React + Vite frontend and an Express + PostgreSQL backend. Supports email/password and optional Google OAuth sign-in.

## Highlights

- JWT-based authentication with PostgreSQL-backed users
- Optional Google OAuth login flow
- Docker Compose quickstart for app + database
- Health endpoint at `/api/health`

## Architecture

- `frontend/`: React + Vite client
- `backend/`: Express API, PostgreSQL, JWT
- `docker-compose.yml`: app + database stack

## Quick Start

### Docker (recommended)

```bash
copy docker.env.example .env

docker compose up -d
```

Open `http://localhost:8080` (or the `APP_PORT` you set).

### Local Development

Backend:

```bash
cd backend
npm install
```

Create `backend/.env` with these keys:

```dotenv
DB_HOST=localhost
DB_PORT=5432
DB_NAME=auth_app
DB_USER=postgres
DB_PASSWORD=postgres
DB_SSL=false
JWT_SECRET=change_this_jwt_secret
GOOGLE_CLIENT_ID=
PORT=5000
```

Start the API server:

```bash
npm run dev
```

Frontend:

```bash
cd frontend
npm install
npm run dev
```

## Configuration

Backend `.env` keys:

- DB_HOST
- DB_PORT
- DB_NAME
- DB_USER
- DB_PASSWORD
- DB_SSL
- JWT_SECRET
- GOOGLE_CLIENT_ID (optional)
- PORT

Docker `.env` keys are listed in `docker.env.example`.

## Scripts

Backend:

- `npm run dev`
- `npm start`

Frontend:

- `npm run dev`
- `npm run build`
- `npm run preview`

## Deployment

See `DOCKER_QUICKSTART.md` and `AWS_DEPLOYMENT.md` for container and AWS setup.
