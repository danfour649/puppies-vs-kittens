#!/bin/bash
# Run all PvK test suites headless; log per-suite results.
GODOT=~/godot-dl/Godot_v4.7-stable_linux.x86_64
PROJ=~/pvk-integration-work/godot3d
OUT=${1:-~/pvk-integration-work/suite-results}
mkdir -p "$OUT"
cd ~/pvk-integration-work
run() {
  local name="$1" scene="$2"
  echo "=== SUITE $name ($scene) ===" >> "$OUT/summary.txt"
  timeout 600 "$GODOT" --headless --path "$PROJ" "res://$scene" > "$OUT/$name.log" 2>&1
  echo "exit=$?" >> "$OUT/summary.txt"
  grep -E "passed|PASS|passed:|Pass|assert" "$OUT/$name.log" | tail -3 >> "$OUT/summary.txt"
  grep -c "SCRIPT ERROR" "$OUT/$name.log" | sed "s/^/script_errors=/" >> "$OUT/summary.txt"
}
: > "$OUT/summary.txt"
run smoke tests/smoke.tscn
run duo duo/tests_duo.tscn
run massey tests/test_massey.tscn
run basement zones/basement/tests_basement.tscn
run attic zones/attic/tests_attic.tscn
run outside zones/outside/tests_outside.tscn
run occupants occupants/tests_occupants.tscn
run ai ai/tests_ai.tscn
run hoarder zones/basement/tests_hoarder.tscn
run dressing house/tests_dressing.tscn
run yard zones/outside/tests_yard_life.tscn
run night zones/basement/tests_night.tscn
run fidelity tests/test_fidelity.tscn
echo "ALL DONE" >> "$OUT/summary.txt"
