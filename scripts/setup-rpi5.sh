#!/bin/bash
# Setup script for Antimony Labs on RPi5

set -e

echo "╔══════════════════════════════════════════╗"
echo "║   Antimony Labs - RPi5 Setup             ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root (sudo)"
  exit 1
fi

# Update system
echo "📦 Updating system packages..."
apt-get update -qq

# Install Docker
echo "🐳 Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    systemctl enable docker
    systemctl start docker
    echo "✅ Docker installed"
else
    echo "✅ Docker already installed"
fi

# Install Docker Compose
echo "📦 Installing Docker Compose..."
if ! docker compose version &> /dev/null; then
    apt-get install -y docker-compose-plugin
    echo "✅ Docker Compose installed"
else
    echo "✅ Docker Compose already installed"
fi

# Install Python dependencies for LLM coordinator
echo "🐍 Installing Python dependencies..."
apt-get install -y python3 python3-pip python3-venv
pip3 install --break-system-packages redis asyncio websockets httpx

# Create data directories
echo "📁 Creating data directories..."
mkdir -p data/{postgres,redis,qdrant,gitea,ipfs,artifacts}

# Set permissions
chmod -R 755 data/

# Create environment file if it doesn't exist
if [ ! -f .env ]; then
    echo "⚙️  Creating .env file..."
    cp .env.example .env
    echo "⚠️  Please edit .env and set your passwords!"
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Setup Complete!                        ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "1. Edit .env file:        nano .env"
echo "2. Start services:        docker compose up -d"
echo "3. Check status:          docker compose ps"
echo "4. View logs:             docker compose logs -f"
echo "5. Start LLM coordinator: python3 scripts/llm-coordinator.py claude-rpi5"
echo ""
