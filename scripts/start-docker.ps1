param(
  [switch]$Rebuild,
  [switch]$FollowLogs,
  [switch]$CheckHealth,
  [int]$AppPort
)

$ErrorActionPreference = 'Stop'

function Fail {
  param([string]$Message)
  Write-Error $Message
  exit 1
}

function Get-EnvValue {
  param(
    [string]$FilePath,
    [string]$Key
  )

  if (-not (Test-Path $FilePath)) {
    return $null
  }

  foreach ($line in Get-Content $FilePath) {
    $trimmed = $line.Trim()
    if (-not $trimmed -or $trimmed.StartsWith('#')) {
      continue
    }

    $parts = $trimmed -split '=', 2
    if ($parts.Count -ne 2) {
      continue
    }

    if ($parts[0].Trim() -eq $Key) {
      return $parts[1].Trim()
    }
  }

  return $null
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

if ($AppPort -gt 0) {
  $env:APP_PORT = [string]$AppPort
}

$effectiveAppPort = $env:APP_PORT
if (-not $effectiveAppPort) {
  $effectiveAppPort = Get-EnvValue -FilePath '.env' -Key 'APP_PORT'
}
if (-not $effectiveAppPort) {
  $effectiveAppPort = '8080'
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
Write-Host "  App:    http://localhost:$effectiveAppPort"
Write-Host "  Health: http://localhost:$effectiveAppPort/api/health"

if ($CheckHealth) {
  $healthParams = @{}
  if ($AppPort -gt 0) {
    $healthParams.AppPort = $AppPort
  }
  & (Join-Path $scriptDir 'check-docker-health.ps1') @healthParams
}

if ($FollowLogs) {
  & docker compose logs -f app
}
