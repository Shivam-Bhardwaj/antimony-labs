#!/bin/bash
# Setup script for Antimony Labs on xps2018 (WSL2/Linux development machine)

set -e

echo "╔══════════════════════════════════════════╗"
echo "║   Antimony Labs - xps2018 Setup          ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Detect environment
if grep -qi microsoft /proc/version; then
    echo "🐧 Detected: WSL2 environment"
    IS_WSL=true
else
    echo "🐧 Detected: Native Linux"
    IS_WSL=false
fi

echo "👤 User: $(whoami)"
echo "🖥️  Host: $(hostname)"
echo ""

# Deployment mode selection
echo "Select deployment mode:"
echo "1) Full Stack (all Docker services + LLM coordinators)"
echo "2) Development (full stack + dev tools, hot-reload)"
echo "3) LLM Coordinators Only (connect to RPi5's services)"
echo ""
read -p "Enter choice [1-3]: " MODE

case $MODE in
    1)
        DEPLOY_MODE="full"
        echo "📦 Selected: Full Stack deployment"
        ;;
    2)
        DEPLOY_MODE="dev"
        echo "🛠️  Selected: Development environment"
        ;;
    3)
        DEPLOY_MODE="llm-only"
        echo "🧠 Selected: LLM Coordinators Only"
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""

# Check if running as root for full/dev modes
if [ "$DEPLOY_MODE" != "llm-only" ] && [ "$EUID" -ne 0 ]; then
    echo "❌ Full/Dev modes require root access"
    echo "Run: sudo ./scripts/setup-xps2018.sh"
    exit 1
fi

# Install Docker (for full/dev modes)
if [ "$DEPLOY_MODE" != "llm-only" ]; then
    echo "🐳 Installing Docker..."
    if ! command -v docker &> /dev/null; then
        if [ "$IS_WSL" = true ]; then
            echo "📝 WSL2 detected - install Docker Desktop on Windows"
            echo "   Download from: https://www.docker.com/products/docker-desktop"
            echo ""
            read -p "Press Enter after installing Docker Desktop..."
        else
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh
            rm get-docker.sh
            systemctl enable docker
            systemctl start docker
        fi
        echo "✅ Docker installed"
    else
        echo "✅ Docker already installed"
    fi

    # Install Docker Compose
    echo "📦 Installing Docker Compose..."
    if ! docker compose version &> /dev/null; then
        apt-get update -qq
        apt-get install -y docker-compose-plugin
        echo "✅ Docker Compose installed"
    else
        echo "✅ Docker Compose already installed"
    fi
fi

# Install Python dependencies
echo "🐍 Installing Python dependencies..."
if [ "$EUID" -eq 0 ]; then
    apt-get update -qq
    apt-get install -y python3 python3-pip python3-venv
    pip3 install --break-system-packages redis asyncio websockets httpx
else
    # Non-root install
    pip3 install --user --break-system-packages redis asyncio websockets httpx 2>/dev/null || \
        pip install --user --break-system-packages redis asyncio websockets httpx
fi

# Create data directories (for full/dev modes)
if [ "$DEPLOY_MODE" != "llm-only" ]; then
    echo "📁 Creating data directories..."
    mkdir -p data/{postgres,redis,qdrant,gitea,ipfs,artifacts}
    chmod -R 755 data/
fi

# Create environment file
if [ ! -f .env ]; then
    echo "⚙️  Creating .env file..."
    cp .env.example .env

    if [ "$DEPLOY_MODE" = "llm-only" ]; then
        # For LLM-only mode, point to RPi5 services
        read -p "Enter RPi5 IP address [10.0.0.207]: " RPI5_IP
        RPI5_IP=${RPI5_IP:-10.0.0.207}

        sed -i "s|postgres:5432|$RPI5_IP:5432|g" .env
        sed -i "s|redis:6379|$RPI5_IP:6379|g" .env
        sed -i "s|qdrant:6333|$RPI5_IP:6333|g" .env
        sed -i "s|gitea:3000|$RPI5_IP:3000|g" .env
        sed -i "s|ipfs:5001|$RPI5_IP:5001|g" .env
    fi

    echo "⚠️  Please edit .env and set your passwords!"
fi

# Development mode specific setup
if [ "$DEPLOY_MODE" = "dev" ]; then
    echo "🛠️  Setting up development environment..."

    # Install Node.js for console-ui development
    if ! command -v node &> /dev/null; then
        echo "📦 Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs
        echo "✅ Node.js installed"
    fi

    # Install console-ui dependencies
    if [ -d "console-ui" ]; then
        echo "📦 Installing console-ui dependencies..."
        cd console-ui
        npm install
        cd ..
        echo "✅ console-ui ready"
    fi

    # Create development docker-compose override
    cat > docker-compose.dev.yml << 'EOF'
version: '3.8'

services:
  api:
    environment:
      - LOG_LEVEL=DEBUG
      - ENVIRONMENT=development
    volumes:
      - ./services/api:/app:rw
    command: uvicorn main:app --host 0.0.0.0 --port 8000 --reload
EOF
    echo "✅ Development overrides created"
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Setup Complete!                        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

case $DEPLOY_MODE in
    full)
        echo "Next steps:"
        echo "1. Edit .env file:        nano .env"
        echo "2. Start services:        docker compose up -d"
        echo "3. Check status:          docker compose ps"
        echo "4. View logs:             docker compose logs -f"
        echo "5. Start LLM coordinators:"
        echo "   python3 scripts/llm-coordinator.py claude-xps2018 &"
        echo "   python3 scripts/llm-coordinator.py codex-xps2018 &"
        ;;
    dev)
        echo "Next steps:"
        echo "1. Edit .env file:        nano .env"
        echo "2. Start services:        docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d"
        echo "3. Start console UI:      cd console-ui && npm run dev"
        echo "4. Access API:            http://localhost:8000/docs"
        echo "5. Access Console UI:     http://localhost:3001"
        echo "6. Start LLM coordinators:"
        echo "   python3 scripts/llm-coordinator.py claude-xps2018 &"
        ;;
    llm-only)
        echo "Next steps:"
        echo "1. Verify RPi5 is accessible:"
        echo "   curl http://$RPI5_IP:8000/api/system/status"
        echo "2. Start LLM coordinators:"
        echo "   python3 scripts/llm-coordinator.py claude-xps2018 &"
        echo "   python3 scripts/llm-coordinator.py codex-xps2018 &"
        echo ""
        echo "Resource usage: xps2018 will only run LLM coordinators,"
        echo "                connecting to RPi5's services"
        ;;
esac

echo ""
