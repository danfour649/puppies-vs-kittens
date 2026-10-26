#!/usr/bin/env bash
# Export the GL Compatibility web build into godot3d/build/web.
# GitHub Actions and Vercel both run this, so a merge to main can
# publish the same pack to Pages and to the Vercel project.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$HOME/godot/Godot_v4.7-stable_linux.x86_64}"
OUT="$ROOT/godot3d/build/web"

if [[ ! -x "$GODOT" ]]; then
  mkdir -p "$HOME/godot" "$HOME/.local/share/godot/export_templates/4.7.stable"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/godot.zip" "https://github.com/godotengine/godot-builds/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip"
  curl -fsSL -o "$tmp/templates.tpz" "https://github.com/godotengine/godot-builds/releases/download/4.7-stable/Godot_v4.7-stable_export_templates.tpz"
  unzip -q "$tmp/godot.zip" -d "$HOME/godot"
  unzip -q "$tmp/templates.tpz" -d "$tmp/templates"
  cp -a "$tmp/templates/templates/." "$HOME/.local/share/godot/export_templates/4.7.stable/"
  chmod +x "$GODOT"
  rm -rf "$tmp"
fi

mkdir -p "$OUT"
"$GODOT" --headless --path "$ROOT/godot3d" --import --quit
"$GODOT" --headless --path "$ROOT/godot3d" --export-release "Web" "$OUT/index.html"
test -f "$OUT/index.html"
test -f "$OUT/index.wasm"
test -f "$OUT/index.pck"
echo "web export: pck $(stat -c%s "$OUT/index.pck") bytes, wasm $(stat -c%s "$OUT/index.wasm") bytes"
