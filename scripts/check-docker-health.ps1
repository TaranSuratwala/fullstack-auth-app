param(
  [int]$TimeoutSeconds = 90,
  [int]$PollSeconds = 3,
  [int]$AppPort,
  [int]$AppPortSecond
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

function Wait-Until {
  param(
    [scriptblock]$Condition,
    [string]$Description,
    [int]$Timeout,
    [int]$Poll
  )

  $deadline = (Get-Date).AddSeconds($Timeout)
  while ((Get-Date) -lt $deadline) {
    try {
      if (& $Condition) {
        Write-Host "OK: $Description"
        return
      }
    } catch {
      # Retry until timeout.
    }
    Start-Sleep -Seconds $Poll
  }

  Fail "Timed out waiting for: $Description"
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

if ($AppPort -gt 0) {
  $env:APP_PORT = [string]$AppPort
}

if ($AppPortSecond -gt 0) {
  $env:APP_PORT_SECOND = [string]$AppPortSecond
}

$effectiveAppPort = $env:APP_PORT
if (-not $effectiveAppPort) {
  $effectiveAppPort = Get-EnvValue -FilePath '.env' -Key 'APP_PORT'
}
if (-not $effectiveAppPort) {
  $effectiveAppPort = '8080'
}

$effectiveAppPortSecond = $env:APP_PORT_SECOND
if (-not $effectiveAppPortSecond) {
  $effectiveAppPortSecond = Get-EnvValue -FilePath '.env' -Key 'APP_PORT_SECOND'
}
if (-not $effectiveAppPortSecond) {
  $effectiveAppPortSecond = '8081'
}

$healthUrl = "http://localhost:$effectiveAppPort/api/health"
$healthUrlSecond = "http://localhost:$effectiveAppPortSecond/api/health"

Wait-Until -Description 'authvault-db container running' -Timeout $TimeoutSeconds -Poll $PollSeconds -Condition {
  $running = (& docker inspect -f '{{.State.Running}}' authvault-db 2>$null).Trim()
  return $running -eq 'true'
}

Wait-Until -Description 'authvault-app container running' -Timeout $TimeoutSeconds -Poll $PollSeconds -Condition {
  $running = (& docker inspect -f '{{.State.Running}}' authvault-app 2>$null).Trim()
  return $running -eq 'true'
}

Wait-Until -Description 'PostgreSQL health is healthy' -Timeout $TimeoutSeconds -Poll $PollSeconds -Condition {
  $status = (& docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' authvault-db 2>$null).Trim()
  return $status -eq 'healthy'
}

Wait-Until -Description 'AuthVault HTTP health endpoint responds' -Timeout $TimeoutSeconds -Poll $PollSeconds -Condition {
  $res = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 10
  return $res.StatusCode -eq 200
}

if ($effectiveAppPortSecond -ne $effectiveAppPort) {
  Wait-Until -Description 'AuthVault second-port health endpoint responds' -Timeout $TimeoutSeconds -Poll $PollSeconds -Condition {
    $res = Invoke-WebRequest -Uri $healthUrlSecond -UseBasicParsing -TimeoutSec 10
    return $res.StatusCode -eq 200
  }
}

Write-Host ''
Write-Host 'Docker stack health check passed.'
Write-Host "  App:    http://localhost:$effectiveAppPort"
Write-Host "  Health: $healthUrl"
Write-Host "  App 2:  http://localhost:$effectiveAppPortSecond"
Write-Host "  Health: $healthUrlSecond"
