#!/usr/bin/env bash
# Installs Godot 4.7.2 (Linux x86_64) for headless use in cloud/CI sessions and prints the
# path to the binary. Idempotent: does nothing if it is already installed.
# Usage: GODOT="$(tools/setup_godot.sh)"
set -euo pipefail

VERSION="4.7.2-stable"
# /opt/godot is where the cloud environment's setup script installs it (cached between
# sessions, see docs/CLOUD_SETUP.md); otherwise fall back to a per-user location.
if [ -z "${GODOT_HOME:-}" ] && [ -x "/opt/godot/Godot_v${VERSION}_linux.x86_64" ]; then
	GODOT_HOME="/opt/godot"
fi
DEST="${GODOT_HOME:-$HOME/.local/share/godot/$VERSION}"
BIN="$DEST/Godot_v${VERSION}_linux.x86_64"
URL="https://github.com/godotengine/godot/releases/download/$VERSION/Godot_v${VERSION}_linux.x86_64.zip"

if [ ! -x "$BIN" ]; then
	mkdir -p "$DEST"
	tmp="$(mktemp -d)"
	trap 'rm -rf "$tmp"' EXIT
	echo "Downloading Godot $VERSION..." >&2
	curl -fsSL -o "$tmp/godot.zip" "$URL"
	if command -v unzip > /dev/null; then
		unzip -q -o "$tmp/godot.zip" -d "$DEST"
	else
		python3 -c "import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$tmp/godot.zip" "$DEST"
	fi
	chmod +x "$BIN"
fi

echo "$BIN"
