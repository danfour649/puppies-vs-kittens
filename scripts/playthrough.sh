#!/usr/bin/env bash
# Scripted playthrough under Xvfb. Prints nothing on its own;
# the Godot tool writes PNGs and stats.json into PLAYTHROUGH_OUT.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$HOME/godot/Godot_v4.7-stable_linux.x86_64}"
OUT="${PLAYTHROUGH_OUT:-$ROOT/godot3d/build/playthrough}"

if [[ ! -x "$GODOT" ]]; then
  mkdir -p "$HOME/godot"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/godot.zip" "https://github.com/godotengine/godot-builds/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip"
  unzip -q "$tmp/godot.zip" -d "$HOME/godot"
  chmod +x "$GODOT"
  rm -rf "$tmp"
fi

if ! command -v xvfb-run >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y xvfb
fi

mkdir -p "$OUT"
export PLAYTHROUGH_OUT="$OUT"
# Software GL. Forward+ wants Vulkan, which this runner does not have.
# Travel and framing are what this job watches.
xvfb-run -a -s "-screen 0 1280x800x24" \
  "$GODOT" --audio-driver Dummy --rendering-method gl_compatibility \
  --resolution 1152x648 \
  --path "$ROOT/godot3d" res://tools/playthrough.tscn
test -f "$OUT/stats.json"
test -f "$OUT/yard.png"
test -f "$OUT/ground_floor.png"
test -f "$OUT/basement.png"
test -f "$OUT/attic.png"
