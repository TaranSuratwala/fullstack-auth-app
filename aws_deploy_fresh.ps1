param(
  [string]$StatePath = "$HOME\.aws\authvault-20260408123928-state.json"
)

$ErrorActionPreference = 'Stop'
$aws = "$env:ProgramFiles\Amazon\AWSCLIV2\aws.exe"

if (!(Test-Path $StatePath)) {
  throw "State file not found: $StatePath"
}

$state = Get-Content $StatePath | ConvertFrom-Json

$keyName = "$($state.prefix)-key"
$keyPath = "$HOME\.ssh\$keyName.pem"
New-Item -ItemType Directory -Path "$HOME\.ssh" -Force | Out-Null

$keyExists = (& "$aws" ec2 describe-key-pairs --region $state.region --key-names $keyName --query "KeyPairs[0].KeyName" --output text --no-cli-pager 2>$null)
if ($LASTEXITCODE -ne 0 -or $keyExists -eq 'None') {
  $keyMaterial = & "$aws" ec2 create-key-pair --region $state.region --key-name $keyName --query "KeyMaterial" --output text --no-cli-pager

  if ($keyMaterial -match '\\n') {
    $keyMaterial = $keyMaterial -replace '\\n', "`n"
  }

  if ($keyMaterial -notmatch "`n" -and $keyMaterial -match '-----BEGIN RSA PRIVATE KEY-----\s+(?<body>.+)\s+-----END RSA PRIVATE KEY-----') {
    $body = ($matches.body -replace '\s+', "`n")
    $keyMaterial = "-----BEGIN RSA PRIVATE KEY-----`n$body`n-----END RSA PRIVATE KEY-----`n"
  }

  [System.IO.File]::WriteAllText($keyPath, $keyMaterial, [System.Text.UTF8Encoding]::new($false))
  icacls $keyPath /inheritance:r | Out-Null
  icacls $keyPath /grant:r "$env:USERNAME:R" | Out-Null
}

$userDataTemplate = @'
#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y ca-certificates curl gnupg git nginx postgresql-client
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

cd /home/ubuntu
if [ ! -d fullstack-auth-app ]; then
  git clone https://github.com/TaranSuratwala/fullstack-auth-app.git
fi
chown -R ubuntu:ubuntu /home/ubuntu/fullstack-auth-app

cat > /home/ubuntu/fullstack-auth-app/backend/config/db.js <<'EOFDB'
const { Pool } = require('pg');

const useSsl =
  process.env.DB_SSL === 'true' || process.env.PGSSLMODE === 'require';

const pool = new Pool({
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT, 10),
  database: process.env.DB_NAME,
  ssl: useSsl ? { rejectUnauthorized: false } : false,
});

pool.on('connect', () => {
  console.log('Connected to PostgreSQL database');
});

pool.on('error', (err) => {
  console.error('Unexpected error on idle PostgreSQL client:', err);
  process.exit(-1);
});

module.exports = pool;
EOFDB
chown ubuntu:ubuntu /home/ubuntu/fullstack-auth-app/backend/config/db.js

cat > /home/ubuntu/fullstack-auth-app/backend/.env <<'EOFENV'
DB_USER=postgres
DB_PASSWORD=__DB_PASSWORD__
DB_HOST=__RDS_ENDPOINT__
DB_PORT=5432
DB_NAME=auth_app
DB_SSL=true
JWT_SECRET=__JWT_SECRET__
GOOGLE_CLIENT_ID=__GOOGLE_CLIENT_ID__
PORT=5000
EOFENV
chown ubuntu:ubuntu /home/ubuntu/fullstack-auth-app/backend/.env

sudo -u ubuntu -H bash -lc 'cd /home/ubuntu/fullstack-auth-app/backend; npm install'
sudo -u ubuntu -H bash -lc 'cd /home/ubuntu/fullstack-auth-app/frontend; npm install; npm run build'

mkdir -p /var/www/authvault
rsync -a --delete /home/ubuntu/fullstack-auth-app/frontend/dist/ /var/www/authvault/
chown -R www-data:www-data /var/www/authvault

cat > /etc/systemd/system/authvault-backend.service <<'EOFSVC'
[Unit]
Description=AuthVault Backend Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/fullstack-auth-app/backend
ExecStart=/usr/bin/node /home/ubuntu/fullstack-auth-app/backend/server.js
Restart=always
RestartSec=3
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOFSVC

cat > /etc/systemd/system/authvault-backend@.service <<'EOFSVCTPL'
[Unit]
Description=AuthVault Backend Service on port %i
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/fullstack-auth-app/backend
Environment=PORT=%i
Environment=NODE_ENV=production
ExecStart=/usr/bin/node /home/ubuntu/fullstack-auth-app/backend/server.js
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOFSVCTPL

cat > /etc/nginx/sites-available/authvault <<'EOFNGINX'
server {
    listen 80 default_server;
    server_name _;

  root /var/www/authvault;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

  server {
    listen 8080 default_server;
    server_name _;

    root /var/www/authvault;
    index index.html;

    location / {
      try_files $uri $uri/ /index.html;
    }

    location /api/ {
      proxy_pass http://127.0.0.1:5001;
      proxy_http_version 1.1;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
    }
  }
EOFNGINX

rm -f /etc/nginx/sites-enabled/*
ln -sf /etc/nginx/sites-available/authvault /etc/nginx/sites-enabled/authvault
nginx -t

systemctl daemon-reload
systemctl enable authvault-backend
systemctl restart authvault-backend
systemctl enable authvault-backend@5001
systemctl restart authvault-backend@5001
systemctl enable nginx
systemctl restart nginx
'@

$userData = $userDataTemplate.Replace('__DB_PASSWORD__', $state.dbPassword)
$userData = $userData.Replace('__RDS_ENDPOINT__', $state.rdsEndpoint)
$userData = $userData.Replace('__JWT_SECRET__', $state.jwtSecret)

$googleClientId = ''
if ($state.PSObject.Properties.Name -contains 'googleClientId' -and $state.googleClientId) {
  $googleClientId = $state.googleClientId
} elseif ($env:GOOGLE_CLIENT_ID) {
  $googleClientId = $env:GOOGLE_CLIENT_ID
}

$userData = $userData.Replace('__GOOGLE_CLIENT_ID__', $googleClientId)
$userData = $userData -replace "`r`n", "`n"

$userDataPath = Join-Path $env:TEMP "$($state.prefix)-userdata.sh"
[System.IO.File]::WriteAllText($userDataPath, $userData, [System.Text.UTF8Encoding]::new($false))

$instanceName = "$($state.prefix)-ec2"
$instanceId = (& "$aws" ec2 run-instances --region $state.region --image-id $state.amiId --instance-type t3.micro --key-name $keyName --security-group-ids $state.appSgId --subnet-id $state.subnetIds[0] --user-data "file://$userDataPath" --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instanceName}]" --query "Instances[0].InstanceId" --output text --no-cli-pager).Trim()

& "$aws" ec2 wait instance-running --region $state.region --instance-ids $instanceId --no-cli-pager
& "$aws" ec2 wait instance-status-ok --region $state.region --instance-ids $instanceId --no-cli-pager

$publicIp = (& "$aws" ec2 describe-instances --region $state.region --instance-ids $instanceId --query "Reservations[0].Instances[0].PublicIpAddress" --output text --no-cli-pager).Trim()

$state | Add-Member -NotePropertyName instanceId -NotePropertyValue $instanceId -Force
$state | Add-Member -NotePropertyName instanceName -NotePropertyValue $instanceName -Force
$state | Add-Member -NotePropertyName publicIp -NotePropertyValue $publicIp -Force
$state | Add-Member -NotePropertyName keyName -NotePropertyValue $keyName -Force
$state | Add-Member -NotePropertyName keyPath -NotePropertyValue $keyPath -Force
$state | Add-Member -NotePropertyName userDataPath -NotePropertyValue $userDataPath -Force

$state | ConvertTo-Json -Depth 6 | Set-Content -Path $StatePath -Encoding UTF8

Write-Output "STATE_PATH=$StatePath"
Write-Output "INSTANCE_ID=$instanceId"
Write-Output "PUBLIC_IP=$publicIp"
Write-Output "KEY_PATH=$keyPath"
Write-Output "USERDATA_PATH=$userDataPath"
Write-Output "APP_URL=http://$publicIp"
Write-Output "HEALTH_URL=http://$publicIp/api/health"
