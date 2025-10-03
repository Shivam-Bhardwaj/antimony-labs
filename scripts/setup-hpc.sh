#!/bin/bash
# Setup script for Antimony Labs on HPC server

set -e

echo "╔══════════════════════════════════════════╗"
echo "║   Antimony Labs - HPC Setup              ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Check if running as current user (not root on HPC)
echo "👤 User: $(whoami)"
echo "🖥️  Host: $(hostname)"
echo ""

# Install Python dependencies for LLM coordinator
echo "🐍 Installing Python dependencies..."
pip3 install --user --break-system-packages redis asyncio websockets httpx 2>/dev/null || \
    pip install --user --break-system-packages redis asyncio websockets httpx

# Create environment file if it doesn't exist
if [ ! -f .env ]; then
    echo "⚙️  Creating .env file..."
    cp .env.example .env
    # Update HPC-specific settings
    sed -i 's|http://localhost|http://console.antimony-labs.org|g' .env
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   HPC Setup Complete!                    ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "HPC will run LLM coordinators only (no Docker services)"
echo ""
echo "To start LLM coordinators:"
echo "  python3 scripts/llm-coordinator.py claude-hpc &"
echo "  python3 scripts/llm-coordinator.py codex-hpc &"
echo ""
echo "Resource allocation: 50% (16 cores, 16GB RAM) reserved for Antimony Labs"
echo ""
