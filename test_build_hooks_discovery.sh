#!/bin/bash
# Why: proves the real hook-discovery artifact finds *.sh hooks and skips tracked .stub examples.

set -uo pipefail
cd "$(dirname "$0")"

echo "Testing scripts/run-hooks.sh build-hook discovery..."

mkdir -p .scratch/tmp
WORKDIR="$(mktemp -d .scratch/tmp/build-hooks-test.XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/build.d"
cp hooks.d/build.d/00-example.sh.stub "$WORKDIR/build.d/00-example.sh.stub"
cat > "$WORKDIR/build.d/10-marker.sh" <<EOF
#!/bin/sh
touch "$WORKDIR/marker"
EOF
chmod +x "$WORKDIR/build.d/10-marker.sh"
# Synthetic .stub fixture proves the *.sh glob excludes it, not just that the real stub is a no-op.
cat > "$WORKDIR/build.d/20-should-not-run.sh.stub" <<EOF
#!/bin/sh
touch "$WORKDIR/stub-ran"
EOF
chmod +x "$WORKDIR/build.d/20-should-not-run.sh.stub"

sh ./scripts/run-hooks.sh "$WORKDIR/build.d"

fail=0

if [ -f "$WORKDIR/marker" ]; then
  echo "PASS: real *.sh hook was discovered and executed"
else
  echo "FAIL: *.sh hook was not executed"
  fail=1
fi

if [ -f "$WORKDIR/stub-ran" ]; then
  echo "FAIL: tracked .stub example was executed — it must never run"
  fail=1
else
  echo "PASS: tracked .stub example was correctly skipped"
fi

if [ "$fail" -ne 0 ]; then
  echo "❌ build-hook discovery test failed"
  exit 1
fi

echo "✅ scripts/run-hooks.sh discovers real hooks and skips .stub examples"
