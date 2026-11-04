#!/bin/sh
# Build and install the Vibival flatpak for the current user.
#   tools/build-flatpak.sh            build + install
#   tools/build-flatpak.sh --bundle   also write vibival.flatpak
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
flatpak-builder --user --install --force-clean --repo=repo \
  build-dir flatpak/top.dns7.vibival.yml
if [ "${1:-}" = "--bundle" ]; then
  # The Godot BaseApp is baked into the app; only the Freedesktop runtime is
  # fetched from Flathub when the bundle is installed.
  flatpak build-bundle \
    --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo \
    repo vibival.flatpak top.dns7.vibival
  echo "wrote $ROOT/vibival.flatpak"
fi
