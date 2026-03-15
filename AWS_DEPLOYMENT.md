# AWS Deployment Guide — AuthVault Full-Stack App

This guide walks you through deploying the full-stack authentication app on **AWS** using **EC2** (for the app), **RDS** (for PostgreSQL), and **Nginx** (as a reverse proxy).

---

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                  AWS Cloud                       │
│                                                  │
│  ┌──────────────────────────────────────────┐    │
│  │          EC2 Instance (Ubuntu)           │    │
│  │                                          │    │
│  │  ┌──────────┐    ┌──────────────────┐    │    │
│  │  │  Nginx   │───▶│  Node.js (PM2)   │    │    │
│  │  │ :80/:443 │    │  Backend :5000   │    │    │
│  │  └──────────┘    └──────────────────┘    │    │
│  │       │                    │              │    │
│  │       │ serves static      │ queries      │    │
│  │       ▼                    ▼              │    │
│  │  React Build        ┌──────────┐          │    │
│  │  (dist/)            │ AWS RDS  │          │    │
│  │                     │ PostgreSQL│          │    │
│  │                     └──────────┘          │    │
│  └──────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

---

## Prerequisites

- An **AWS account**
- **AWS CLI** installed on your local machine (optional but helpful)
- A **key pair** (.pem file) for SSH access — create one in the EC2 console

---

## Step 1: Create an RDS PostgreSQL Instance

1. Go to **AWS Console → RDS → Create database**
2. Choose **Standard Create** → **PostgreSQL**
3. Select **Free Tier** (if eligible) or the tier you need
4. Configure:
   | Setting | Value |
   |---------|-------|
   | DB Instance Identifier | `authvault-db` |
   | Master Username | `postgres` |
   | Master Password | *(choose a strong password)* |
   | DB Instance Class | `db.t3.micro` (Free Tier) |
   | Storage | 20 GB gp2 |
   | Public Access | **No** (for security) |
5. Under **VPC Security Group**, create a new one called `authvault-db-sg`
6. Click **Create Database** and wait for it to become **Available**
7. Note down the **Endpoint** (e.g., `authvault-db.xxxx.us-east-1.rds.amazonaws.com`)

### Create the database:
Connect to the RDS instance from your EC2 instance (after launching it) and run:
```bash
psql -h <RDS_ENDPOINT> -U postgres
CREATE DATABASE auth_app;
\q
```

---

## Step 2: Launch an EC2 Instance

1. Go to **AWS Console → EC2 → Launch Instance**
2. Configure:
   | Setting | Value |
   |---------|-------|
   | Name | `authvault-server` |
   | AMI | **Ubuntu Server 22.04 LTS** |
   | Instance Type | `t2.micro` (Free Tier) |
   | Key Pair | Select or create a `.pem` key pair |
   | Storage | 15 GB gp3 |
3. Under **Network Settings**, create a security group with these rules:

   | Type | Port | Source |
   |------|------|--------|
   | SSH | 22 | Your IP |
   | HTTP | 80 | 0.0.0.0/0 |
   | HTTPS | 443 | 0.0.0.0/0 |

4. Click **Launch Instance**

### Update RDS Security Group
Go to **RDS → Security Groups → authvault-db-sg** and add an inbound rule:
| Type | Port | Source |
|------|------|--------|
| PostgreSQL | 5432 | EC2 Security Group ID |

This allows the EC2 instance to connect to the database.

---

## Step 3: Connect to EC2 and Install Dependencies

```bash
# SSH into your EC2 instance
ssh -i "your-key.pem" ubuntu@<EC2_PUBLIC_IP>

# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Verify installation
node -v  # Should show v20.x
npm -v

# Install PM2 (process manager)
sudo npm install -g pm2

# Install Nginx
sudo apt install -y nginx

# Install PostgreSQL client (to connect to RDS)
sudo apt install -y postgresql-client

# Verify Nginx is running
sudo systemctl status nginx
```

---

## Step 4: Deploy the Application

### Upload your code to EC2

**Option A — Git (Recommended):**
```bash
# If your code is in a Git repo:
cd /home/ubuntu
git clone <YOUR_REPO_URL> fullstack-auth-app
```

**Option B — SCP (from your local machine):**
```bash
# From your local machine (PowerShell/Terminal):
scp -i "your-key.pem" -r ./fullstack-auth-app ubuntu@<EC2_PUBLIC_IP>:/home/ubuntu/
```

### Install dependencies and build

```bash
cd /home/ubuntu/fullstack-auth-app

# Backend
cd backend
npm install

# Create .env file
cat > .env << 'EOF'
DB_USER=postgres
DB_PASSWORD=YOUR_RDS_PASSWORD
DB_HOST=YOUR_RDS_ENDPOINT
DB_PORT=5432
DB_NAME=auth_app
JWT_SECRET=GENERATE_A_STRONG_SECRET_HERE
PORT=5000
EOF

# Frontend
cd ../frontend
npm install
npm run build
```

> **💡 Tip:** Generate a strong JWT secret with: `node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"`

---

## Step 5: Start the Backend with PM2

```bash
cd /home/ubuntu/fullstack-auth-app/backend

# Start with PM2
pm2 start server.js --name "authvault-backend"

# Save the PM2 process list (survives reboots)
pm2 save

# Set PM2 to start on boot
pm2 startup
# Copy and run the command it outputs (starts with sudo)

# Check status
pm2 status
pm2 logs authvault-backend
```

---

## Step 6: Configure Nginx

```bash
# Create Nginx config
sudo nano /etc/nginx/sites-available/authvault
```

Paste the following configuration:

```nginx
server {
    listen 80;
    server_name _;   # Replace with your domain if you have one

    # Serve React frontend
    root /home/ubuntu/fullstack-auth-app/frontend/dist;
    index index.html;

    # Frontend routes — let React Router handle them
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API requests to Express backend
    location /api/ {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Enable the site and restart Nginx:

```bash
# Enable the config
sudo ln -s /etc/nginx/sites-available/authvault /etc/nginx/sites-enabled/

# Remove default config
sudo rm /etc/nginx/sites-enabled/default

# Test Nginx config
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

---

## Step 7: Verify Deployment

1. Open your browser and navigate to `http://<EC2_PUBLIC_IP>`
2. You should see the **AuthVault login page**
3. Register a new account → you should be redirected to the dashboard
4. Log out and log back in → should work correctly

---

## Step 8 (Optional): Custom Domain + SSL

### Point your domain to EC2
1. Go to your domain registrar (e.g., GoDaddy, Namecheap, Route 53)
2. Create an **A record** pointing to your EC2 **Elastic IP**
   - First, allocate an **Elastic IP** in EC2 and associate it with your instance (so the IP doesn't change)

### Install SSL with Let's Encrypt
```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Get SSL certificate (replace with your domain)
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Auto-renewal is set up automatically. Test it with:
sudo certbot renew --dry-run
```

Update your Nginx config's `server_name` to your domain:
```nginx
server_name yourdomain.com www.yourdomain.com;
```

---

## Useful Commands Reference

| Task | Command |
|------|---------|
| View backend logs | `pm2 logs authvault-backend` |
| Restart backend | `pm2 restart authvault-backend` |
| Check backend status | `pm2 status` |
| Restart Nginx | `sudo systemctl restart nginx` |
| View Nginx logs | `sudo tail -f /var/log/nginx/error.log` |
| Connect to RDS | `psql -h <RDS_ENDPOINT> -U postgres -d auth_app` |
| Rebuild frontend | `cd frontend && npm run build` |
| Update app from Git | `git pull && cd backend && npm install && pm2 restart authvault-backend && cd ../frontend && npm install && npm run build` |

---

## Security Checklist

- [x] Passwords hashed with bcrypt (salt rounds: 12)
- [x] JWT tokens with 24h expiration
- [ ] Change the `JWT_SECRET` in `.env` to a strong random value
- [ ] Set `Public Access` to **No** for RDS
- [ ] Restrict SSH access to your IP only
- [ ] Enable SSL/HTTPS with Let's Encrypt
- [ ] Set up AWS CloudWatch for monitoring
- [ ] Enable RDS automated backups
