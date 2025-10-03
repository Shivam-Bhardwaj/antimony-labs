# Antimony Labs - Quick Start Guide

## 🚀 Setup (5 minutes)

### Step 1: On RPi5 (this machine)

```bash
cd /root/antimony-labs

# Run setup script (installs Docker, dependencies)
sudo ./scripts/setup-rpi5.sh

# Edit environment variables (optional)
nano .env

# Start all services
docker compose up -d

# Wait ~30 seconds for services to initialize
docker compose ps

# Start LLM coordinators
python3 scripts/llm-coordinator.py claude-rpi5 &
python3 scripts/llm-coordinator.py codex-rpi5 &
```

### Step 2: Deploy to HPC

```bash
cd /root/antimony-labs

# Deploy to HPC (copies files, sets up environment)
./scripts/deploy-to-hpc.sh

# SSH to HPC and start coordinators
ssh curious@10.0.0.205
cd ~/antimony-labs
python3 scripts/llm-coordinator.py claude-hpc &
python3 scripts/llm-coordinator.py codex-hpc &
```

## ✅ Verify Everything Works

```bash
# Check system status
curl http://localhost:8000/api/system/status

# Should show all 4 LLMs:
# - claude-rpi5: online
# - codex-rpi5: online
# - claude-hpc: online
# - codex-hpc: online
```

## 🧪 Test with First Idea

```bash
curl -X POST http://localhost:8000/api/ideas/submit \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Smart Plant Watering System",
    "description": "IoT device that monitors soil moisture and waters plants automatically using Arduino"
  }'

# Watch the logs to see LLMs coordinate
docker compose logs -f api
```

## 📊 Access Services

- **API**: http://localhost:8000
- **Gitea**: http://localhost:3000
- **Qdrant**: http://localhost:6333/dashboard
- **IPFS**: http://localhost:5001/webui

## 🛠️ Common Commands

```bash
# View all services
docker compose ps

# View logs
docker compose logs -f

# Restart a service
docker compose restart api

# Stop everything
docker compose down

# Full reset (WARNING: deletes all data)
docker compose down -v
rm -rf data/*
```

## 🐛 Troubleshooting

### LLMs not connecting?
```bash
# Check Redis
docker compose logs redis

# Restart coordinators
pkill -f llm-coordinator
python3 scripts/llm-coordinator.py claude-rpi5 &
python3 scripts/llm-coordinator.py codex-rpi5 &
```

### Database issues?
```bash
# Rebuild database
docker compose down
rm -rf data/postgres/*
docker compose up -d
```

## 📚 Next Steps

1. Read full README.md
2. Explore API docs: http://localhost:8000/docs
3. Set up blockchain integration for NFT minting
4. Build web UI for users
5. Start accepting contributions!

---

**Welcome to Antimony Labs - where ideas become reality through collaboration! 🚀**
