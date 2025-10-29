#!/usr/bin/env bash
set -euo pipefail

# Check for raw networking usage outside of generated client
hits=$(grep -R --line-number --include="*.swift" -E '\bURLSession\.shared|URLRequest\(' focusmate/ || true)

# Allow in the generated folder and internal networking implementation
bad=$(echo "$hits" | grep -v 'ios/Generated/APIClient' | grep -v 'NetworkingProtocol.swift' | grep -v 'NewAPIClient.swift' || true)

if [[ -n "$bad" ]]; then
  echo "❌ Raw networking detected outside Generated/APIClient:"
  echo "$bad"
  exit 1
fi

echo "✅ No raw networking found."
