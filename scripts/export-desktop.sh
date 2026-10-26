#!/usr/bin/env bash
# Export Forward+ desktop builds (Linux, Windows, macOS) into
# godot3d/build/desktop. The project renderer stays forward_plus;
# only the web feature falls back to GL Compatibility.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$HOME/godot/Godot_v4.7-stable_linux.x86_64}"
OUT="$ROOT/godot3d/build/desktop"
PROJ="$ROOT/godot3d/project.godot"

grep -q 'renderer/rendering_method="forward_plus"' "$PROJ"
grep -q 'renderer/rendering_method.web="gl_compatibility"' "$PROJ"

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
"$GODOT" --headless --path "$ROOT/godot3d" --export-release "Linux" "$OUT/WillieAndAggie.x86_64"
"$GODOT" --headless --path "$ROOT/godot3d" --export-release "Windows Desktop" "$OUT/WillieAndAggie.exe"
"$GODOT" --headless --path "$ROOT/godot3d" --export-release "macOS" "$OUT/WillieAndAggie-macos.zip"

rm -f "$OUT/WillieAndAggie-linux-x86_64.zip" "$OUT/WillieAndAggie-windows-x86_64.zip"
(
  cd "$OUT"
  zip -q -j WillieAndAggie-linux-x86_64.zip WillieAndAggie.x86_64
  zip -q -j WillieAndAggie-windows-x86_64.zip WillieAndAggie.exe
)
test -s "$OUT/WillieAndAggie-linux-x86_64.zip"
test -s "$OUT/WillieAndAggie-windows-x86_64.zip"
test -s "$OUT/WillieAndAggie-macos.zip"
echo "desktop export:"
stat -c '  %n %s bytes' "$OUT"/*.zip
