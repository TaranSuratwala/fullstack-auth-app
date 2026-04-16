param(
  [switch]$Rebuild,
  [switch]$FollowLogs,
  [switch]$CheckHealth
)

$ErrorActionPreference = 'Stop'

function Fail {
  param([string]$Message)
  Write-Error $Message
  exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir '..')
Set-Location $repoRoot

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Fail 'Docker CLI not found. Install Docker Desktop (or Docker Engine + Compose) and retry.'
}

try {
  docker info *> $null
} catch {
  Fail 'Docker engine is not running. Start Docker Desktop and retry.'
}

if (-not (Test-Path '.env')) {
  if (-not (Test-Path 'docker.env.example')) {
    Fail 'Missing docker.env.example. Cannot auto-create .env file.'
  }

  Copy-Item 'docker.env.example' '.env'
  Write-Host 'Created .env from docker.env.example. Update JWT_SECRET before sharing.'
}

$composeArgs = @('compose', 'up', '-d')
if ($Rebuild) {
  $composeArgs = @('compose', 'up', '--build', '-d')
}

Write-Host "Running: docker $($composeArgs -join ' ')"
& docker @composeArgs

if ($LASTEXITCODE -ne 0) {
  Fail 'docker compose up failed.'
}

Write-Host ''
Write-Host 'AuthVault is running:'
Write-Host '  App:    http://localhost:8080'
Write-Host '  Health: http://localhost:8080/api/health'

if ($CheckHealth) {
  & (Join-Path $scriptDir 'check-docker-health.ps1')
}

if ($FollowLogs) {
  & docker compose logs -f app
}
