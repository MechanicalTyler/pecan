#!/bin/sh
# Runs every *.sh file in the given directory in sorted order; .stub files never match.
set -e

dir="$1"

for f in "$dir"/*.sh; do
  [ -e "$f" ] || continue
  echo "Running hook: $f"
  sh "$f"
done
