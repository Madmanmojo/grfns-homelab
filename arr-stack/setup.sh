#!/bin/zsh
# Helper script for Mac Arr Stack setup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Mac Arr Stack Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check Docker
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running!"
    echo "   Please start Docker Desktop and try again."
    exit 1
fi

echo "✅ Docker is running"
echo ""

# Start containers
echo "📦 Starting containers..."
docker-compose up -d

echo ""
echo "⏳ Waiting for services to initialize (30 seconds)..."
sleep 30

echo ""
echo "✅ Containers started!"
echo ""
echo "🌐 Access the web UIs:"
echo "   Radarr:   http://localhost:7878"
echo "   Sonarr:   http://localhost:8989"
echo "   Whisparr: http://localhost:6969"
echo ""
echo "📋 Next steps:"
echo "   1. Open each app in browser (setup wizard will appear)"
echo "   2. Configure root folders:"
echo "      - Radarr:   /movies"
echo "      - Sonarr:   /tv"
echo "      - Whisparr: /adult"
echo "   3. Get API keys from Settings → General → Security"
echo "   4. Update sync script:"
echo "      ~/scripts/active/seedbox/sync_radarr_seedbox_to_mac.py"
echo ""
echo "📊 Check container status:"
echo "   docker-compose ps"
echo ""














