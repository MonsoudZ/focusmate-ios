#!/usr/bin/env bash
set -euo pipefail
periphery scan \
  --project focusmate.xcodeproj \
  --schemes "focusmate" \
  --targets "focusmate" \
  --retain-public \
  --skip-build \
  --index-store-path /Users/monsoudzanaty/Library/Developer/Xcode/DerivedData/focusmate-eqxdtgsujrrgsrdmwpdzbzcdxmgy/Index.noindex/DataStore
