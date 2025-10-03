# Antimony Labs Migration Guide

This document captures the quickest path for moving the current RPi5 "stack" to a fresh Linux host while keeping the RPi5 as the public entry point (reverse proxy) together with Cloudflare.

## 1. Snapshot the Current RPi5 State

1. **Record secrets** – copy `.env`, `~/.git-credentials`, and any API keys under `paper-trail/`.
2. **Export databases**  
   ```bash
   cd /root/antimony-labs
   docker exec antimony-postgres pg_dumpall -U antimony > backups/postgres-$(date +%F).sql
   ```
3. **Archive volumes** (optional but fastest for a full clone):  
   ```bash
   tar -czf backups/postgres-data.tar.gz data/postgres
   tar -czf backups/qdrant-data.tar.gz data/qdrant
   tar -czf backups/gitea-data.tar.gz data/gitea
   tar -czf backups/ipfs-data.tar.gz data/ipfs
   ```
4. **Console UI bundle** – `pm2 save` captures the console process config (`pm2 startup` if you rebuild elsewhere).

## 2. Prepare The New Host

1. Install dependencies:
   ```bash
   sudo apt update
   sudo apt install -y curl git ufw
   curl -fsSL https://get.docker.com | sudo bash
   sudo usermod -aG docker $USER
   sudo apt install -y docker-compose-plugin
   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
   sudo apt install -y nodejs
   sudo npm install -g pm2
   ```
2. Copy the repository: `git clone https://github.com/Shivam-Bhardwaj/antimony-labs.git` (or secure copy from RPi5 if local changes exist).
3. Restore `.env`, credentials, and `paper-trail/SHARED_MEMORY.json` if needed.
4. Restore data either from SQL dump (`psql`) or tar archives.

## 3. Start Services On The New Host

1. Bring Docker stack up:
   ```bash
   cd ~/antimony-labs
   docker compose up -d
   ```
2. Launch console UI via PM2 (same commands as RPi5):
   ```bash
   cd console-ui
   npm install --production
   pm2 start npm --name console-ui -- start
   pm2 save
   ```
3. Confirm health:
   - `docker ps`
   - `curl http://localhost:8000/api/system/status`
   - `pm2 status`

## 4. Re-point The RPi5 Reverse Proxy When Ready

1. On RPi5, update the upstream targets in `/etc/nginx/sites-available/antimony-labs` and `console.antimony-labs.org` to use the new machine’s internal IP (e.g. `proxy_pass http://10.0.0.210:8000;`).
2. Reload nginx: `sudo systemctl reload nginx`.
3. Keep Docker and PM2 processes running on the new host; stop them on the RPi5 to avoid duplicate workers.

## 5. Cloudflare Configuration

1. Keep all DNS records proxied (orange cloud).
2. Set SSL/TLS mode to **Flexible** (origin served over HTTP) or upload a Cloudflare Origin Certificate to the new host if you prefer **Full (strict)**.
3. Optional: Lock access to Cloudflare IP ranges only – add `set_real_ip_from` and `deny` rules in nginx if you want to drop non-Cloudflare traffic.

## 6. Decommission Steps (Optional)

- Disable Docker stack on RPi5: `docker compose down`.
- Stop PM2 console UI on RPi5: `pm2 stop console-ui` & `pm2 delete console-ui`.
- Leave nginx + Cloudflare configuration on RPi5 so it continues to behave like the RPi3b entry point.

## Checklist

- [ ] New host running Docker stack and console UI.
- [ ] DNS still points to RPi5 IP (only nginx remains).
- [ ] RPi5 nginx upstreams now forward to new host IPs.
- [ ] Cloudflare SSL mode confirmed (Flexible or Full with origin cert).
- [ ] Paper-trail shared memory updated after migration.

Keep this file with the repository so the next migration is copy/paste friendly.
