# AutoCrate Development Setup - Recovery Guide

## Location
- **HPC Server:** curious@10.0.0.205
- **Project Path:** `/home/curious/AutoCrate`
- **GitHub Repo:** https://github.com/Shivam-Bhardwaj/AutoCrate (private)

## Quick Start Commands

### SSH to HPC
```bash
ssh curious@10.0.0.205
# Password: qwqw
```

### Start Dev Server
```bash
cd ~/AutoCrate
npm run dev
# Access at: http://10.0.0.205:3000
```

### Check if Running
```bash
ps aux | grep "next dev"
# Or check logs:
tail -f ~/autocrate-dev.log
```

### Stop Dev Server
```bash
pkill -f "next dev"
```

## Git Workflow

### Pull Latest Changes
```bash
cd ~/AutoCrate
git pull origin main
```

### Make Changes and Commit
```bash
git add .
git commit -m "Your commit message"
git push origin main
# Auto-deploys to Vercel
```

### Check Status
```bash
git status
git log --oneline -5
```

## Claude/Codex Access

The LLM coordinators on HPC can assist with development:
- **claude-hpc:** Architecture, refactoring, analysis
- **codex-hpc:** Code generation, debugging

Check if running:
```bash
ps aux | grep llm-coordinator
```

Restart if needed:
```bash
cd ~/antimony-labs
python3 scripts/llm-coordinator.py claude-hpc &
python3 scripts/llm-coordinator.py codex-hpc &
```

## Credentials

All credentials stored in: `/root/antimony-labs/.credentials`
- GitHub Token: `<redacted>`
- GitHub User: `shivam-bhardwaj`

Git credentials cached in: `~/.git-credentials` (both RPi5 and HPC)

## Common Tasks

### Install Dependencies
```bash
npm install
```

### Build for Production
```bash
npm run build
```

### Run Tests (if any)
```bash
npm test
```

## Vercel Deployment

Any push to `main` branch auto-deploys to Vercel.

Check deployment status:
- Visit Vercel dashboard
- Or check GitHub Actions (if configured)

## Troubleshooting

### Port 3000 Already in Use
```bash
pkill -f "next dev"
# Wait 5 seconds
npm run dev
```

### Git Issues
```bash
# Reset credentials (replace with the token stored in `.credentials`)
source /root/antimony-labs/.credentials
echo "https://$GITHUB_USERNAME:$GITHUB_TOKEN@github.com" > ~/.git-credentials
chmod 600 ~/.git-credentials
git config --global credential.helper store
```

### Dependencies Issues
```bash
rm -rf node_modules package-lock.json
npm install
```

## Session Recovery

If you lose terminal session:
1. SSH back to HPC: `ssh curious@10.0.0.205`
2. Check if dev server still running: `ps aux | grep next`
3. If running, connect to http://10.0.0.205:3000
4. If not running, restart: `cd ~/AutoCrate && npm run dev`

---

**Last Updated:** 2025-10-02
**HPC IP:** 10.0.0.205
**RPi5 IP:** 10.0.0.207
