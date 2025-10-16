#!/usr/bin/env bash
set -euo pipefail

# Guard against ProfileScreenScrollable imports sneaking back in
# (The class itself still exists in profile_screen_scrollable.dart with a tripwire)
if rg -q "import .*/profile_screen_scrollable\.dart" lib --type dart 2>/dev/null; then
  echo "❌ Found ProfileScreenScrollable imports in lib/ (use ProfileScreenRouter via NavX.goProfile)"
  rg "import .*/profile_screen_scrollable\.dart" lib --type dart -n
  exit 1
fi

echo "✅ No legacy ProfileScreenScrollable imports in lib/"
exit 0
