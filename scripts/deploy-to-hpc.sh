#!/bin/bash
# Deploy Antimony Labs to HPC server

set -e

HPC_HOST="curious@10.0.0.205"
HPC_DIR="~/antimony-labs"

echo "╔══════════════════════════════════════════╗"
echo "║   Deploying to HPC Server                ║"
echo "╚══════════════════════════════════════════╝"
echo ""

echo "📦 Copying files to HPC..."
ssh $HPC_HOST "mkdir -p $HPC_DIR"

# Copy only necessary files (not data volumes)
rsync -avz --exclude='data/' \
    --exclude='__pycache__/' \
    --exclude='.git/' \
    --exclude='*.pyc' \
    ./ $HPC_HOST:$HPC_DIR/

echo "✅ Files copied to HPC"

echo ""
echo "🔧 Setting up HPC environment..."
ssh $HPC_HOST "cd $HPC_DIR && bash scripts/setup-hpc.sh"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Deployment Complete!                   ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "To start LLM coordinators on HPC:"
echo "ssh $HPC_HOST"
echo "cd $HPC_DIR"
echo "python3 scripts/llm-coordinator.py claude-hpc &"
echo "python3 scripts/llm-coordinator.py codex-hpc &"
echo ""
