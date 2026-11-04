#!/bin/sh
# Wayland only: the sandbox has no X11 socket, so never try the x11 driver.
headless=false
for arg in "$@"; do
  [ "$arg" = "--" ] && break
  [ "$arg" = "--headless" ] && headless=true
done
if ! $headless; then
  sock=${WAYLAND_DISPLAY:-wayland-0}
  case $sock in /*) ;; *) sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/$sock" ;; esac
  if [ ! -S "$sock" ]; then
    echo "Vibival needs a Wayland session (no Wayland display found)." >&2
    echo "X11 is not supported. Log in to a Wayland session, or run it in a nested compositor such as weston or cage." >&2
    exit 1
  fi
fi
exec /app/bin/godot-runner --display-driver wayland \
  --main-pack /app/share/vibival/vibival.zip "$@"
