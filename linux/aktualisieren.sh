#!/bin/sh
# Post & Pakete für Linux auf eine neue Version bringen (aufgerufen von der App über paketbote-update:<Version>)
#   lädt post-und-pakete-linux-<Version>.tar.gz von GitHub, führt dessen installieren.sh aus, startet die App neu
set -eu
V="${1:-}"
V="${V#paketbote-update:}"
V="${V#//}"
case "$V" in
  ''|*[!0-9.]*) echo "Ungültige Version: $V" >&2; exit 1 ;;
esac
SPERRE="${XDG_RUNTIME_DIR:-/tmp}/paketbote-update.sperre"
mkdir "$SPERRE" 2>/dev/null || exit 0          # läuft schon (App und Plasma-Widget gleichzeitig)
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" "$SPERRE"' EXIT
URL="https://github.com/Teyro/Post-und-Pakete/releases/download/v$V/post-und-pakete-linux-$V.tar.gz"
melden() { command -v notify-send >/dev/null 2>&1 && notify-send -a "Post & Pakete" -i "${XDG_DATA_HOME:-$HOME/.local/share}/paketbote/paketbote.svg" "Post & Pakete" "$1" || true; }
if command -v curl >/dev/null 2>&1; then
  curl -fsSL -o "$TMP/p.tar.gz" "$URL" || { melden "Update auf $V konnte nicht geladen werden."; exit 1; }
elif command -v wget >/dev/null 2>&1; then
  wget -q -O "$TMP/p.tar.gz" "$URL" || { melden "Update auf $V konnte nicht geladen werden."; exit 1; }
else
  melden "Für Updates wird curl oder wget gebraucht."; exit 1
fi
tar xzf "$TMP/p.tar.gz" -C "$TMP"
test -x "$TMP/post-und-pakete/installieren.sh" || test -f "$TMP/post-und-pakete/installieren.sh" || { melden "Update-Paket unvollständig."; exit 1; }
LIEF=0
pgrep -f "paketbote/app/main.qml" >/dev/null 2>&1 && LIEF=1
sh "$TMP/post-und-pakete/installieren.sh" >/dev/null
if [ "$LIEF" = 1 ]; then
  pkill -f "paketbote/app/main.qml" 2>/dev/null || true
  sleep 1
  (gtk-launch de.teyro.paketbote >/dev/null 2>&1 || kioclient exec "${XDG_DATA_HOME:-$HOME/.local/share}/applications/de.teyro.paketbote.desktop" >/dev/null 2>&1 || true) &
fi
melden "Auf Version $V aktualisiert. Das Plasma-Widget gilt ab der nächsten Anmeldung."
