# Antimony Labs - Paper-Trail System

**A persistent, collaborative knowledge system where ideas evolve through cryptographically-verified contributions.**

## 🧠 What is Paper-Trail?

Paper-Trail is the "brain" of Antimony Labs - a system that:
- Accepts ideas in plain English (for normal people)
- Coordinates 4 LLM instances (Claude Code + Codex on RPi5 and HPC)
- Tracks every contribution cryptographically
- Grows smarter with each collaboration
- Survives restarts (fully persistent)
- Rewards contributors with NFT tokens

## 🏗️ Architecture

```
User (plain English)
    ↓
antimony-labs.org (RPi5)
    ├─ Claude Code (planning, reasoning)
    ├─ Codex (code generation)
    └─ Paper-Trail API
           ↓
      [Redis Queue]
           ↓
HPC Server (10.0.0.205)
    ├─ Claude Code (heavy analysis)
    ├─ Codex (heavy code gen)
    └─ Compute workers
```

## 📦 Components

### Services (Docker Compose)
- **PostgreSQL** - Core database with full schema
- **Redis** - Inter-LLM communication
- **Qdrant** - Vector database for semantic search
- **Gitea** - Self-hosted Git server
- **IPFS** - Decentralized file storage
- **Paper-Trail API** - FastAPI coordination server

### LLM Instances
1. **claude-rpi5** - User interaction, planning
2. **codex-rpi5** - Quick code generation
3. **claude-hpc** - Heavy reasoning, analysis
4. **codex-hpc** - Large code generation tasks

## 🚀 Quick Start

### On RPi5 (console.antimony-labs.org)

```bash
cd /root/antimony-labs

# Copy environment file
cp .env.example .env
nano .env  # Edit with your settings

# Start all services
docker-compose up -d

# Start LLM coordinator for RPi5 instances
python3 scripts/llm-coordinator.py claude-rpi5 &
python3 scripts/llm-coordinator.py codex-rpi5 &

# Check status
curl http://localhost:8000/api/system/status
```

### On HPC (10.0.0.205)

```bash
# Copy project from RPi5
scp -r root@console.antimony-labs.org:/root/antimony-labs ~/

cd ~/antimony-labs

# Start only the coordinator (not full docker stack)
python3 scripts/llm-coordinator.py claude-hpc &
python3 scripts/llm-coordinator.py codex-hpc &
```

## 📚 Database Schema

The paper-trail brain stores:
- **Users** - Invite-only participants
- **Ideas** - User submissions with uniqueness/quality scores
- **PRDs** - Generated product requirements
- **NFT Tokens** - Minted for approved ideas
- **Contributions** - Code, CAD files, documentation
- **Contribution Graph** - Relationships between work
- **LLM Sessions** - Conversation history
- **Brain Learnings** - Patterns the system learns
- **Crypto Ledger** - Immutable audit trail

## 🔗 API Endpoints

### User Interaction
- `POST /api/ideas/submit` - Submit an idea in plain English
- `GET /api/ideas/{idea_id}` - Get idea status
- `GET /api/paper-trail/{type}/{id}` - View contribution history

### LLM Coordination
- `POST /api/llm/message` - Send message between LLMs
- `WS /ws/llm/{llm_name}` - WebSocket for real-time LLM communication
- `POST /api/system/llm/heartbeat/{llm}` - LLM heartbeat

### System
- `GET /api/system/status` - Check all LLM instances
- `POST /api/paper-trail/update` - Update the brain

## 🧪 Example Workflow

```python
# User submits idea
curl -X POST http://localhost:8000/api/ideas/submit \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Solar-powered water filter",
    "description": "A low-cost water purification system using solar energy"
  }'

# System automatically:
# 1. Claude-rpi5 analyzes the idea
# 2. Delegates to Claude-hpc for deep analysis
# 3. Codex-hpc generates initial code structure
# 4. Codex-rpi5 creates web interface
# 5. Everything stored in paper-trail
# 6. NFT minted if quality threshold met
```

## 🔐 Security

- Invite-only system (no public signup)
- Cryptographic signatures on all contributions
- SSH key-based communication (RPi5 ↔ HPC)
- Immutable ledger of all changes
- NFT timestamps for proof of creation

## 📊 Resource Allocation

### HPC Server (i9-14900KF, 32 cores, 32GB RAM)
- **50% for Antimony Labs** - 16 cores, 16GB RAM
- **50% for personal projects** - 16 cores, 16GB RAM
- Personal projects can overflow when Antimony idle

## 🎯 Roadmap

- [x] Design architecture
- [x] Set up RPi5 ↔ HPC SSH connection
- [x] Create database schema
- [x] Build Docker Compose stack
- [x] Implement LLM coordination layer
- [ ] Add blockchain integration (NFT minting)
- [ ] Build web UI for users
- [ ] Implement CAD file processing (STEP format)
- [ ] Add semantic search (Qdrant embeddings)
- [ ] Create contribution reward system

## 🤝 Contributing

This is the ultimate open-source project. Everything except the RPi 3B reverse proxy is open source.

Users contribute by:
1. Submitting ideas
2. Writing code
3. Creating CAD designs
4. Refining documentation
5. Improving the system itself

All contributions are cryptographically signed and added to paper-trail.

## 📄 License

Open source - specific license TBD

## 🔧 Troubleshooting

### LLM instances not connecting
```bash
# Check Redis
docker logs antimony-redis

# Check API
docker logs antimony-api

# Restart coordinator
pkill -f llm-coordinator
python3 scripts/llm-coordinator.py claude-rpi5 &
```

### Database connection issues
```bash
# Check PostgreSQL
docker logs antimony-postgres

# Recreate database
docker-compose down
rm -rf data/postgres/*
docker-compose up -d
```

---

**Built with ❤️ for collaboration and open innovation**
