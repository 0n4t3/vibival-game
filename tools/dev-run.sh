#!/bin/sh
# Run the game from source with the Flathub Godot BaseApp runtime (dev only).
# Usage: tools/dev-run.sh [godot args] [-- game args]
# Example: tools/dev-run.sh --headless -- --start=swamp --selftest
# Dev runs use X11 or headless; the shipped flatpak is Wayland-only.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${VIBIVAL_OUT:-$ROOT/.dev-out}
mkdir -p "$OUT"
exec flatpak run --filesystem="$ROOT/game:ro" --filesystem="$OUT" \
	--socket=x11 --socket=pulseaudio --device=dri \
	--command=godot-runner org.godotengine.godot.BaseApp//4.7 \
	--path "$ROOT/game" --display-driver x11 "$@"
