#!/bin/bash
# Why: guards against command injection into docker run/bake via a malicious or mistyped pecan.env value.

set -uo pipefail
cd "$(dirname "$0")"

echo "Testing scripts/pecan.sh config-value validation..."

# shellcheck source=scripts/pecan.sh
. ./scripts/pecan.sh

fail=0

assert_valid() {
  if _pecan_validate "$1"; then
    echo "PASS: '$1' accepted"
  else
    echo "FAIL: '$1' should have been accepted"
    fail=1
  fi
}

assert_invalid() {
  if _pecan_validate "$1"; then
    echo "FAIL: '$1' should have been rejected"
    fail=1
  else
    echo "PASS: '$1' rejected"
  fi
}

assert_valid "/Users/example/projects"
assert_valid "pecan-host"
assert_valid "pecan.local"
assert_valid ""

assert_invalid "/Users/example; rm -rf /"
assert_invalid '$(whoami)'
assert_invalid "host\`id\`"
assert_invalid "path with spaces"
assert_invalid "pipe|here"
assert_invalid "amp&here"
assert_invalid "redirect>here"

if [ "$fail" -ne 0 ]; then
  echo "❌ pecan.env validation test failed"
  exit 1
fi

echo "✅ pecan.env validation rejects shell metacharacters correctly"
