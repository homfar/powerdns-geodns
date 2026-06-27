#!/usr/bin/env bash
set -euo pipefail

required_files=(
  "README.md"
  "SECURITY.md"
  "LICENSE"
  "lua-global/10-geo-policy.lua"
  "docs/pdns.conf.example"
  "docs/geoip-backend.yaml.example"
  "docs/RELEASE_NOTES_v1.0.0.md"
  "zones/examples/example.com.yaml"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing required file: $file" >&2
    exit 1
  fi
done

# Ensure public examples use placeholders instead of real deployment values.
if grep -RniE "([0-9]{1,3}\.){3}[0-9]{1,3}" zones/examples docs --exclude='*.md' | grep -vE "127\.0\.0\.1|0\.0\.0\.0|example|TTL|SOA"; then
  echo "Potential real IPv4 address found in public example files." >&2
  exit 1
fi


# Keep this repository brand-neutral.
if grep -RniE "ipm[y]p|ipm[y]p\.com|ipm[y]p\.ir" . --exclude-dir=.git; then
  echo "Project-specific brand reference found. Keep this repository brand-neutral." >&2
  exit 1
fi

# Ensure MaxMind databases are not present.
if find . -name '*.mmdb' -o -name '*.mmdb.gz' | grep -q .; then
  echo "MaxMind database files must not be committed." >&2
  exit 1
fi

# Ensure README defaults match Lua defaults.
grep -q "GEOPOLICY_DEBUG = false" lua-global/10-geo-policy.lua
grep -q "GEOPOLICY_DEBUG.*false" README.md

echo "Validation passed."
