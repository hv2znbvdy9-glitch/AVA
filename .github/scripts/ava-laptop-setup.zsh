#!/bin/zsh
# AVA Laptop Setup Script for macOS - Run with sudo
# Usage: sudo zsh ava-laptop-setup.zsh

echo ""
echo "🚀 AVA Laptop Setup Started..."
echo "================================"
echo ""

# Check if running as admin/root
if [[ $EUID -ne 0 ]]; then
   echo "⚠️  This script should be run as root (admin)"
   echo "Try: sudo zsh ava-laptop-setup.zsh"
   exit 1
fi

echo "✅ Running with admin privileges on macOS"
echo ""

# Navigate to repo directory
cd "$(dirname "$0")" || exit
cd ../.. || exit

echo "📁 Working directory: $(pwd)"
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
npm install
if [ $? -ne 0 ]; then
    echo "❌ npm install failed"
    exit 1
fi
echo "✅ Dependencies installed"
echo ""

# Run tests
echo "🧪 Running AVA Tests..."
npm test
echo ""

# Run AVA CLI
echo "🎯 Running AVA CLI..."
npx ava "echo 'AVA is running on your macOS Laptop - ALL SYSTEMS GO!'"
echo ""

# Run Safe Local Node
echo "🔒 Running AVA Safe Local Node..."
npx ava --safe-local-node || true
echo ""

echo ""
echo "================================"
echo "✅ AVA Laptop Setup Complete!"
echo "================================"
echo ""
echo "📝 Next steps:"
echo "   1. AVA is ready to run on your macOS laptop"
echo "   2. Use: npm test"
echo "   3. Use: npx ava \"your-command\""
echo ""
