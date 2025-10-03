# Mobile Access to Antimony Labs

## 🚀 Quick Setup (2 minutes)

### Option 1: Tailscale (Recommended - Secure VPN)

**On your phone:**
1. Install Tailscale app from App Store/Play Store
2. Open this URL to authenticate the RPi5:
   ```
   https://login.tailscale.com/a/1b7f0cc601479c
   ```
3. Log in with your account
4. Approve the device "antimony-labs"

**Once connected, access from your phone:**
- SSH: `ssh root@antimony-labs` (or use the Tailscale IP)
- API: `http://antimony-labs:8000`
- Gitea: `http://antimony-labs:3000`
- Full network: Access HPC too!

**Benefits:**
- ✅ Encrypted VPN tunnel
- ✅ Works anywhere (cellular, WiFi)
- ✅ No port forwarding needed
- ✅ Access all services (RPi5 + HPC)
- ✅ SSH from phone
- ✅ Magic DNS (use hostnames, not IPs)

---

### Option 2: Public Access via Cloudflare (Already configured!)

**Access from anywhere:**
- Main site: https://antimony-labs.org
- Console: https://console.antimony-labs.org
- API: https://api.antimony-labs.org

**Cloudflare provides:**
- ✅ SSL/TLS encryption
- ✅ DDoS protection
- ✅ CDN caching
- ✅ Works on any network

**Limitation:** Only web services, no direct SSH

---

### Option 3: Cloudflare Tunnel (Most Secure)

**Set up zero-trust access:**

```bash
# On RPi5
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb -o cloudflared.deb
dpkg -i cloudflared.deb

# Authenticate
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create antimony-labs

# Configure tunnel (see cloudflared-config.yml)
# Run tunnel
cloudflared tunnel run antimony-labs
```

**Benefits:**
- ✅ No open ports
- ✅ Zero-trust security
- ✅ Access control per service
- ✅ Works behind NAT
- ✅ CloudflareAccess policies

---

## 📱 Recommended Mobile Apps

### SSH Clients:
- **iOS:** Termius, Blink Shell
- **Android:** Termux, JuiceSSH

### Browser:
- Use any browser to access web services

### Code Editing (optional):
- **VS Code Server** - Run on RPi5, access from phone browser
- **code-server** - Full IDE in browser

---

## 🔧 Setup Commands

### Start Tailscale on RPi5:
```bash
tailscale up --advertise-routes=10.0.0.0/24 --accept-routes --ssh
```

### Check Tailscale Status:
```bash
tailscale status
```

### Get Tailscale IP:
```bash
tailscale ip -4
```

### Start Services:
```bash
cd /root/antimony-labs
docker compose up -d
```

---

## 🌐 Access URLs

### Via Tailscale (after setup):
- SSH: `ssh root@<tailscale-ip>`
- API: `http://<tailscale-ip>:8000`
- Gitea: `http://<tailscale-ip>:3000`

### Via Public Internet:
- https://antimony-labs.org
- https://console.antimony-labs.org
- https://api.antimony-labs.org

---

## 🔐 Security Notes

1. **Tailscale** - Peer-to-peer encrypted VPN
2. **Cloudflare** - Edge security + SSL
3. **Invite-only** - Platform access controlled
4. **SSH keys** - Use keys, not passwords

---

## 🆘 Troubleshooting

### Can't connect via Tailscale?
```bash
# On RPi5
sudo tailscale status
sudo systemctl restart tailscaled
```

### Can't access web services?
```bash
# Check nginx
sudo systemctl status nginx
sudo nginx -t

# Check Docker services
docker compose ps
```

### Forgot Tailscale URL?
Check your Tailscale admin console:
https://login.tailscale.com/admin/machines

---

**You now have 3 ways to access your server from anywhere! 🎉**
