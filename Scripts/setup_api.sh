#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Focusmate API Setup Script"
echo "=============================="

# Check if STAGING_API_URL is set
if [[ -n "${STAGING_API_URL:-}" ]]; then
    echo "✅ STAGING_API_URL is set: $STAGING_API_URL"
else
    echo "⚠️  STAGING_API_URL not set. Using localhost fallback."
    echo "   To set staging URL: export STAGING_API_URL='https://your-api-url.com'"
fi

# Test API connectivity
echo ""
echo "🌐 Testing API connectivity..."

API_URL="${STAGING_API_URL:-http://localhost:3000}"
echo "   Testing: $API_URL"

# Test if the API is reachable
if curl -s --connect-timeout 5 "$API_URL/health" > /dev/null 2>&1; then
    echo "✅ API is reachable"
elif curl -s --connect-timeout 5 "$API_URL" > /dev/null 2>&1; then
    echo "✅ API is reachable (no /health endpoint)"
else
    echo "❌ API is not reachable"
    echo "   Make sure your API server is running at: $API_URL"
    echo ""
    echo "   For development, you can:"
    echo "   1. Start your Rails server: rails server -p 3000"
    echo "   2. Or set STAGING_API_URL to your staging server"
    exit 1
fi

echo ""
echo "🚀 Ready to test the iOS app!"
echo "   Run: xcodebuild -scheme focusmate -destination 'platform=iOS Simulator,name=iPhone 17' build"
