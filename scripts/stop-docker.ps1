param(
  [switch]$RemoveVolumes
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

$composeArgs = @('compose', 'down')
if ($RemoveVolumes) {
  $composeArgs += '-v'
}

Write-Host "Running: docker $($composeArgs -join ' ')"
& docker @composeArgs

if ($LASTEXITCODE -ne 0) {
  Fail 'docker compose down failed.'
}

Write-Host 'AuthVault containers stopped successfully.'
