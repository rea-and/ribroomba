#!/bin/bash
# Regenerates the checked-in Needle dependency graph.
# Run after ANY change to a Component or Dependency protocol.
# Pass --check to fail (without writing) if the checked-in file is stale.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=RibRoomba/Generated/NeedleGenerated.swift
command -v needle >/dev/null || { echo "needle not found: brew install needle"; exit 1; }
if [[ "${1:-}" == "--check" ]]; then
  TMP=$(mktemp)
  needle generate "$TMP" RibRoomba --exclude-suffixes Tests Mocks --exclude-paths Generated >/dev/null
  diff -q "$TMP" "$OUT" >/dev/null && echo "Needle graph up to date" || { echo "NeedleGenerated.swift is stale: run Scripts/generate-needle.sh"; exit 1; }
else
  needle generate "$OUT" RibRoomba --exclude-suffixes Tests Mocks --exclude-paths Generated
fi
