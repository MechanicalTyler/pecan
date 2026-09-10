#!/bin/bash
# Why: proves docker-bake.hcl resolves build args from pecan.env values, not hardcoded defaults.

set -uo pipefail
cd "$(dirname "$0")"

echo "Testing docker-bake.hcl resolves build args from environment..."
# --print is a daemon-less dry run of the resolved config.

mkdir -p .scratch/tmp
SAMPLE_ENV=".scratch/tmp/test-bake-config.env"
cat > "$SAMPLE_ENV" <<'EOF'
PECAN_BASE_IMAGE=node:24-bookworm-slim
PECAN_EXTRA_PACKAGES="jq curl"
PECAN_USER=testuser
PECAN_HOME=/home/testuser
EOF

set -a
. "$SAMPLE_ENV"
set +a

OUTPUT="$(docker buildx bake -f docker-bake.hcl --print pecan 2>&1)"
STATUS=$?

rm -f "$SAMPLE_ENV"

if [ "$STATUS" -ne 0 ]; then
  echo "❌ docker buildx bake --print failed:"
  echo "$OUTPUT"
  exit 1
fi

fail=0
check_contains() {
  if echo "$OUTPUT" | grep -qF "$1"; then
    echo "PASS: output contains $1"
  else
    echo "FAIL: output missing $1"
    fail=1
  fi
}

check_contains '"BASE_IMAGE": "node:24-bookworm-slim"'
check_contains '"EXTRA_PACKAGES": "jq curl"'
check_contains '"PECAN_USER": "testuser"'
check_contains '"PECAN_HOME": "/home/testuser"'

if [ "$fail" -ne 0 ]; then
  echo "❌ docker-bake.hcl config resolution test failed"
  echo "$OUTPUT"
  exit 1
fi

echo "✅ docker-bake.hcl resolves build args from pecan.env-shaped environment"
