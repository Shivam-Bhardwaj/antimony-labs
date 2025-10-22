# Deploying Antimony Labs to xps2018

## Overview

xps2018 is a Dell XPS laptop on the local network (10.0.0.109) used for hosting web applications.

**Multi-Server Architecture** (following shivambhardwaj.com pattern):
- **xps2018** (10.0.0.109) - Primary web server (32GB RAM, x86_64)
- **RPi/sbl1** (10.0.0.174) - Backup server (ARM64, automatic failover)
- **Load Balancing**: Cloudflare Tunnel with 8 connections
- **Failover**: < 1 second if either server fails

## Quick Deploy

### From RPi5 (Recommended)

```bash
# On RPi5 (console.antimony-labs.org)
cd /root/antimony-labs
./scripts/deploy-to-xps2018.sh
```

### Manual Deployment

```bash
# 1. SSH into xps2018
ssh curious@10.0.0.109
# Password: iou

# 2. Clone/update the repository
cd ~
git clone https://github.com/Shivam-Bhardwaj/antimony-labs.git
# OR if already exists:
cd ~/antimony-labs
git pull

# 3. Install dependencies for console-ui
cd ~/antimony-labs/console-ui
npm install

# 4. Build the application
npm run build

# 5. Start the application
npm start
# OR for development with hot-reload:
npm run dev
```

## Web Server Configuration

### Using PM2 (Recommended for Production)

```bash
# Install PM2 globally
sudo npm install -g pm2

# Start console-ui with PM2
cd ~/antimony-labs/console-ui
pm2 start npm --name "antimony-console" -- start

# Save PM2 process list
pm2 save

# Set PM2 to start on boot
pm2 startup
```

### Using nginx Reverse Proxy

```nginx
# /etc/nginx/sites-available/antimony-labs

server {
    listen 80;
    server_name antimony-labs.local 10.0.0.109;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/antimony-labs /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## Environment Configuration

Create `.env.local` in console-ui directory:

```bash
# API endpoint - point to RPi5
NEXT_PUBLIC_API_URL=http://10.0.0.207:8000

# OR if running full stack on xps2018
NEXT_PUBLIC_API_URL=http://localhost:8000
```

## Deployment Modes

### Mode 1: Console UI Only (Recommended)

xps2018 hosts the web interface, connects to RPi5's API.

**Pros:**
- Lightweight
- Easy to manage
- RPi5 handles all backend logic

**Setup:**
```bash
cd ~/antimony-labs/console-ui
npm install
npm run build
pm2 start npm --name "antimony-console" -- start
```

### Mode 2: Full Stack

xps2018 runs all services (PostgreSQL, Redis, API, etc.).

**Pros:**
- Standalone deployment
- Doesn't depend on RPi5

**Setup:**
```bash
cd ~/antimony-labs
./scripts/setup-xps2018.sh
# Choose "Full Stack" when prompted
docker compose up -d
```

### Mode 3: Development Environment

Hot-reload enabled for active development.

**Setup:**
```bash
cd ~/antimony-labs/console-ui
npm run dev
# Access at http://10.0.0.109:3000
```

## Access

- **Console UI:** http://10.0.0.109 (with nginx)
- **Direct (dev):** http://10.0.0.109:3000
- **From phone:** Setup Tailscale (see MOBILE_ACCESS.md)

## Troubleshooting

### Port 3000 already in use
```bash
# Find and kill the process
lsof -ti:3000 | xargs kill -9

# OR using PM2
pm2 delete antimony-console
```

### Application won't start
```bash
# Check logs
pm2 logs antimony-console

# OR for npm
cd ~/antimony-labs/console-ui
npm run dev
# Look for error messages
```

### Can't connect to API
```bash
# Verify RPi5 is accessible
curl http://10.0.0.207:8000/api/system/status

# Check .env.local has correct API URL
cat ~/antimony-labs/console-ui/.env.local
```

### Git authentication issues
```bash
# Setup Git credentials
git config --global user.name "Shivam Bhardwaj"
git config --global user.email "your-email@example.com"

# For private repos, use personal access token
git config --global credential.helper store
git pull
# Enter username and token when prompted
```

## RPi Backup Server Setup (10.0.0.174)

For high availability, deploy to the RPi backup server following the same pattern:

### Initial Setup on RPi

```bash
# SSH to RPi
ssh curious@10.0.0.174
# Password: iou

# Clone repository
cd ~
git clone https://github.com/Shivam-Bhardwaj/antimony-labs.git
cd antimony-labs/console-ui

# Install dependencies
npm install

# Build application
npm run build

# Deploy to /var/www
sudo mkdir -p /var/www/antimony-labs.com
sudo chown -R curious:curious /var/www/antimony-labs.com
rsync -av --delete ./out/ /var/www/antimony-labs.com/
chmod -R 755 /var/www/antimony-labs.com
```

### Configure nginx on RPi

```bash
# Create nginx config
sudo nano /etc/nginx/sites-available/antimony-labs.com

# Add same configuration as xps2018
# Then enable:
sudo ln -s /etc/nginx/sites-available/antimony-labs.com /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Sync from xps2018 to RPi

For quick synchronization after deploying to xps2018:

```bash
# On xps2018
sshpass -p 'iou' rsync -av --delete \
  /var/www/antimony-labs.com/ \
  curious@10.0.0.174:/var/www/antimony-labs.com/
```

### Cloudflare Tunnel Setup

To enable automatic failover:

1. **Install cloudflared on both servers**:
   ```bash
   # On xps2018 and RPi
   wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb  # xps2018
   # or for RPi:
   wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
   sudo dpkg -i cloudflared-*.deb
   ```

2. **Configure tunnel** (following shivambhardwaj.com pattern):
   ```bash
   # Create tunnel
   cloudflared tunnel create antimony-labs-multi

   # Configure tunnel with 8 connections (4 per server)
   # See shivambhardwaj.com deployment for full config
   ```

3. **Start tunnel on both servers**:
   ```bash
   # xps2018 and RPi
   cloudflared tunnel run antimony-labs-multi
   ```

**Result**: Cloudflare automatically load balances between servers with instant failover.

## Updating the Deployment

### Update xps2018 (Primary)

```bash
# SSH to xps2018
ssh curious@10.0.0.109

# Pull latest changes
cd ~/antimony-labs
git pull

# Rebuild and redeploy
cd console-ui
npm install  # If package.json changed
npm run build
rsync -av --delete ./out/ /var/www/antimony-labs.com/
```

### Sync to RPi (Backup)

```bash
# From xps2018, sync to RPi
sshpass -p 'iou' rsync -av --delete \
  /var/www/antimony-labs.com/ \
  curious@10.0.0.174:/var/www/antimony-labs.com/
```

## Automated Deployment Script

See `scripts/deploy-to-xps2018.sh` for automated deployment from RPi5.

---

**Machine Details:**

**Primary Server (xps2018):**
- **Hostname:** xps2018
- **IP:** 10.0.0.109
- **User:** curious
- **RAM:** 32GB
- **Arch:** x86_64
- **OS:** Ubuntu 24.04
- **Purpose:** Primary web hosting

**Backup Server (RPi/sbl1):**
- **Hostname:** sbl1
- **IP:** 10.0.0.174
- **User:** curious
- **RAM:** 7.7GB
- **Arch:** ARM64
- **OS:** Armbian
- **Purpose:** Backup/failover hosting

**Network:**
- **RPi5 (Backend):** 10.0.0.207
- **HPC (Compute):** 10.0.0.205
- **xps2018 (Primary Web):** 10.0.0.109
- **RPi/sbl1 (Backup Web):** 10.0.0.174
