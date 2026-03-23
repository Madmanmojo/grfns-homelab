#!/bin/zsh
# Script to move Docker config to Orange drive

set -e

ORANGE_CONFIG="/Volumes/Orange/docker/arr-stack/config"
LOCAL_CONFIG="$HOME/docker/arr-stack/config"

echo "🔄 Moving Docker config to Orange drive..."
echo ""

# Check if Orange is mounted
if [ ! -d "/Volumes/Orange" ]; then
    echo "❌ Orange drive not mounted!"
    echo "   Please mount the Orange drive and try again."
    exit 1
fi

# Stop containers first
echo "⏹️  Stopping containers..."
cd "$HOME/docker/arr-stack"
docker-compose down

# Create directories on Orange
echo "📁 Creating directories on Orange..."
mkdir -p "$ORANGE_CONFIG"/{radarr,sonarr,whisparr}

# Move existing config if it exists
if [ -d "$LOCAL_CONFIG" ]; then
    echo "📦 Moving existing config..."
    for service in radarr sonarr whisparr; do
        if [ -d "$LOCAL_CONFIG/$service" ]; then
            echo "  Moving $service config..."
            cp -R "$LOCAL_CONFIG/$service"/* "$ORANGE_CONFIG/$service/" 2>/dev/null || true
            # Keep a backup
            mv "$LOCAL_CONFIG/$service" "$LOCAL_CONFIG/${service}.backup.$(date +%Y%m%d)"
        fi
    done
    echo "✅ Config moved (backup kept in $LOCAL_CONFIG)"
else
    echo "ℹ️  No existing config to move"
fi

echo ""
echo "✅ Done! Config is now on Orange drive"
echo ""
echo "🚀 Start containers:"
echo "   cd ~/docker/arr-stack && docker-compose up -d"














