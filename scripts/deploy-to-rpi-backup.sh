#!/bin/bash
# Deploy Antimony Labs console UI to RPi backup server (10.0.0.174)
# Can be run from xps2018 to sync, or standalone on RPi

set -e

RPI_HOST="curious@10.0.0.174"
RPI_PASS="iou"
DEPLOY_PATH="/var/www/antimony-labs.com"

echo "╔══════════════════════════════════════════╗"
echo "║   Deploying to RPi Backup (10.0.0.174)   ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Check if running on xps2018 (to sync) or standalone
CURRENT_HOST=$(hostname)

if [ "$CURRENT_HOST" = "xps2018" ]; then
    # Sync from xps2018 to RPi
    echo "🔄 Syncing from xps2018 to RPi backup..."

    if [ ! -d "$DEPLOY_PATH" ]; then
        echo "❌ Error: $DEPLOY_PATH not found on xps2018"
        echo "   Deploy to xps2018 first!"
        exit 1
    fi

    # Check if sshpass is installed
    if ! command -v sshpass &> /dev/null; then
        echo "📦 Installing sshpass..."
        sudo apt-get update -qq
        sudo apt-get install -y sshpass
    fi

    # Check connectivity
    echo "🔍 Checking if RPi is online..."
    if ! ping -c 1 -W 2 10.0.0.174 &> /dev/null; then
        echo "❌ Cannot reach RPi at 10.0.0.174"
        exit 1
    fi
    echo "✅ RPi is reachable"

    # Ensure directory exists on RPi
    sshpass -p "$RPI_PASS" ssh -o StrictHostKeyChecking=no $RPI_HOST "
        sudo mkdir -p $DEPLOY_PATH
        sudo chown -R \$(whoami):\$(whoami) $DEPLOY_PATH
    "

    # Sync files
    echo "📤 Syncing files to RPi..."
    sshpass -p "$RPI_PASS" rsync -av --delete \
        -e "ssh -o StrictHostKeyChecking=no" \
        $DEPLOY_PATH/ \
        $RPI_HOST:$DEPLOY_PATH/

    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║   Sync Complete!                         ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    echo "✅ Files synchronized to RPi backup server"
    echo "🌐 Access at: http://10.0.0.174"

else
    # Standalone deployment on RPi
    echo "🏗️  Building on RPi..."

    if [ ! -d ~/antimony-labs ]; then
        echo "📦 Cloning repository..."
        cd ~
        git clone https://github.com/Shivam-Bhardwaj/antimony-labs.git
    fi

    cd ~/antimony-labs

    echo "📥 Pulling latest changes..."
    git pull origin master

    cd console-ui

    echo "📦 Installing dependencies..."
    npm install

    echo "🏗️  Building application..."
    npm run build

    if [ ! -d "out" ]; then
        echo "❌ Error: Build output directory 'out' not found"
        exit 1
    fi

    echo "🚀 Deploying to $DEPLOY_PATH..."
    sudo mkdir -p $DEPLOY_PATH
    sudo chown -R $(whoami):$(whoami) $DEPLOY_PATH

    rsync -av --delete ./out/ $DEPLOY_PATH/
    chmod -R 755 $DEPLOY_PATH

    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║   Deployment Complete!                   ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    echo "✅ Console UI deployed to RPi"
    echo "🌐 Access at: http://10.0.0.174"
    echo ""
    echo "📊 Deployment statistics:"
    echo "   - Build directory: $(pwd)/out"
    echo "   - Deploy directory: $DEPLOY_PATH"
    echo "   - Files deployed: $(find $DEPLOY_PATH -type f | wc -l)"
    echo "   - Total size: $(du -sh $DEPLOY_PATH | cut -f1)"
fi

echo ""
echo "📝 Next steps:"
echo "   1. Ensure nginx is configured on RPi"
echo "   2. Set up Cloudflare Tunnel for load balancing"
echo "   3. Test failover by stopping xps2018"
echo ""
