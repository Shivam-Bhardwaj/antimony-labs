#!/bin/bash
# Deploy Antimony Labs to xps2018 laptop
# Run from RPi5 or any machine with network access to xps2018

set -e

# Configuration
XPS2018_HOST="curious@10.0.0.109"
XPS2018_PASS="iou"
XPS2018_DIR="~/antimony-labs"

echo "╔══════════════════════════════════════════╗"
echo "║   Deploying to xps2018 (10.0.0.109)      ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Check if sshpass is installed
if ! command -v sshpass &> /dev/null; then
    echo "📦 Installing sshpass..."
    sudo apt-get update -qq
    sudo apt-get install -y sshpass
fi

# Check connectivity
echo "🔍 Checking if xps2018 is online..."
if ! ping -c 1 -W 2 10.0.0.109 &> /dev/null; then
    echo "❌ Cannot reach xps2018 at 10.0.0.109"
    echo "   Make sure the laptop is powered on and connected to the network"
    exit 1
fi
echo "✅ xps2018 is reachable"

# Select deployment mode
echo ""
echo "Select deployment mode:"
echo "1) Console UI only (recommended - lightweight web interface)"
echo "2) Full Stack (all Docker services)"
echo "3) Development mode (hot-reload enabled)"
echo ""
read -p "Enter choice [1-3]: " MODE

case $MODE in
    1)
        DEPLOY_MODE="console-ui"
        echo "🌐 Deploying Console UI only"
        ;;
    2)
        DEPLOY_MODE="full"
        echo "📦 Deploying Full Stack"
        ;;
    3)
        DEPLOY_MODE="dev"
        echo "🛠️  Deploying Development environment"
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "📦 Creating directory on xps2018..."
sshpass -p "$XPS2018_PASS" ssh -o StrictHostKeyChecking=no $XPS2018_HOST "mkdir -p $XPS2018_DIR"

echo "📤 Copying files to xps2018..."
sshpass -p "$XPS2018_PASS" rsync -avz \
    --exclude='data/' \
    --exclude='__pycache__/' \
    --exclude='.git/' \
    --exclude='*.pyc' \
    --exclude='node_modules/' \
    --exclude='.next/' \
    -e "sshpass -p $XPS2018_PASS ssh -o StrictHostKeyChecking=no" \
    ./ $XPS2018_HOST:$XPS2018_DIR/

echo "✅ Files copied to xps2018"

if [ "$DEPLOY_MODE" = "console-ui" ]; then
    echo ""
    echo "🔧 Setting up Console UI..."

    # Create .env.local pointing to RPi5's API
    sshpass -p "$XPS2018_PASS" ssh -o StrictHostKeyChecking=no $XPS2018_HOST "cat > $XPS2018_DIR/console-ui/.env.local << 'EOF'
# API endpoint - RPi5
NEXT_PUBLIC_API_URL=http://10.0.0.207:8000
EOF"

    # Install dependencies and build
    sshpass -p "$XPS2018_PASS" ssh -o StrictHostKeyChecking=no $XPS2018_HOST "
        cd $XPS2018_DIR/console-ui

        # Check if Node.js is installed
        if ! command -v node &> /dev/null; then
            echo '📦 Installing Node.js...'
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
            sudo apt-get install -y nodejs
        fi

        # Check if nginx is installed
        if ! command -v nginx &> /dev/null; then
            echo '📦 Installing nginx...'
            sudo apt-get update
            sudo apt-get install -y nginx
        fi

        echo '📦 Installing dependencies...'
        npm install

        echo '🏗️  Building application...'
        npm run build

        # Deploy to /var/www (following shivambhardwaj.com pattern)
        echo '🚀 Deploying to /var/www/antimony-labs.com...'
        sudo mkdir -p /var/www/antimony-labs.com
        sudo chown -R \$(whoami):\$(whoami) /var/www/antimony-labs.com

        # Sync build output to deployment directory
        rsync -av --delete ./out/ /var/www/antimony-labs.com/
        chmod -R 755 /var/www/antimony-labs.com

        echo '✅ Console UI deployed!'
        echo '📊 Deployment statistics:'
        echo '   - Files deployed: \$(find /var/www/antimony-labs.com -type f | wc -l)'
        echo '   - Total size: \$(du -sh /var/www/antimony-labs.com | cut -f1)'
    "

    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║   Deployment Complete!                   ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    echo "🌐 Access Console UI at:"
    echo "   http://10.0.0.109"
    echo ""
    echo "📝 Next steps:"
    echo "   1. Configure nginx (see XPS2018_DEPLOYMENT.md)"
    echo "   2. Set up RPi backup server for redundancy"
    echo "   3. Configure Cloudflare Tunnel for public access"

elif [ "$DEPLOY_MODE" = "full" ] || [ "$DEPLOY_MODE" = "dev" ]; then
    echo ""
    echo "🔧 Running setup script..."
    sshpass -p "$XPS2018_PASS" ssh -t -o StrictHostKeyChecking=no $XPS2018_HOST "
        cd $XPS2018_DIR
        chmod +x scripts/setup-xps2018.sh
        echo '$XPS2018_PASS' | sudo -S bash scripts/setup-xps2018.sh
    "

    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║   Deployment Complete!                   ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    echo "To start services on xps2018:"
    echo "ssh $XPS2018_HOST"
    echo "cd $XPS2018_DIR"
    if [ "$DEPLOY_MODE" = "dev" ]; then
        echo "docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d"
        echo "cd console-ui && npm run dev"
    else
        echo "docker compose up -d"
    fi
fi

echo ""
