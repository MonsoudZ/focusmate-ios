#!/usr/bin/env bash
set -euo pipefail

echo "🧪 Testing Focusmate with Mock API"
echo "=================================="

# Enable mock mode
export MOCK_API=true

echo "✅ Mock mode enabled"
echo "   The app will use mock data instead of making real API calls"
echo ""

# Build and run the app
echo "🚀 Building and running the app..."
xcodebuild -scheme focusmate -destination "platform=iOS Simulator,name=iPhone 17" build

echo ""
echo "✅ Build successful! You can now:"
echo "   1. Open the app in Xcode Simulator"
echo "   2. Try signing in with any email/password"
echo "   3. The app will use mock data and work offline"
echo ""
echo "   To disable mock mode: unset MOCK_API"
