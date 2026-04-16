param(
  [int]$TimeoutSeconds = 90,
  [int]$PollSeconds = 3
)

$ErrorActionPreference = 'Stop'

function Fail {
  param([string]$Message)
  Write-Error $Message
  exit 1
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
  $res = Invoke-WebRequest -Uri 'http://localhost:8080/api/health' -UseBasicParsing -TimeoutSec 10
  return $res.StatusCode -eq 200
}

Write-Host ''
Write-Host 'Docker stack health check passed.'
Write-Host '  App:    http://localhost:8080'
Write-Host '  Health: http://localhost:8080/api/health'
