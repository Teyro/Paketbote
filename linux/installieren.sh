#!/bin/sh
# Paketbote für Linux installieren (oder aktualisieren) – ohne Root-Rechte:
#   App:   ~/.local/share/paketbote  + Eintrag im Startmenü
#   Plasma-Widget (wenn KDE Plasma 6 da ist): „Paketbote“ in der Widget-Auswahl
# Braucht: Qt 6 (qml-Programm), Kirigami und das Qt-Quick-Desktop-Design von KDE (bei Plasma schon dabei).
set -eu
HIER="$(cd "$(dirname "$0")" && pwd)"
ZIEL="${XDG_DATA_HOME:-$HOME/.local/share}/paketbote"

# qml-Programm finden (heißt je nach Distribution anders)
QML=""
for k in qml6 qml-qt6 /usr/lib/qt6/bin/qml /usr/lib64/qt6/bin/qml /usr/libexec/qt6/qml /usr/lib/x86_64-linux-gnu/qt6/bin/qml; do
  if command -v "$k" >/dev/null 2>&1; then QML="$(command -v "$k")"; break; fi
done
if [ -z "$QML" ]; then
  echo "Qt 6 fehlt (Programm „qml“). Bitte installieren, z. B.:"
  echo "  Arch: sudo pacman -S qt6-declarative kirigami qqc2-desktop-style"
  echo "  Debian/Ubuntu: sudo apt install qml6-module-* qt6-declarative-dev-tools kirigami2-dev"
  echo "  Fedora: sudo dnf install qt6-qtdeclarative kf6-kirigami kf6-qqc2-desktop-style"
  exit 1
fi

mkdir -p "$ZIEL"
rm -rf "$ZIEL/app" "$ZIEL/gemeinsam"
cp -r "$HIER/app" "$HIER/gemeinsam" "$ZIEL/"
cp "$HIER/paketbote.svg" "$ZIEL/"
cp "$HIER/installieren.sh" "$ZIEL/"

ANW="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$ANW"
cat > "$ANW/de.teyro.paketbote.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Post & Pakete
GenericName=Briefe und Pakete
GenericName[en]=Letters and parcels
Comment=Angekündigte Briefe und Pakete von DHL, Hermes, DPD, GLS, UPS und Amazon
Comment[en]=Announced letters and parcels from DHL, Hermes, DPD, GLS, UPS and Amazon
Exec=env QT_QUICK_CONTROLS_STYLE=org.kde.desktop "$QML" -a widget "$ZIEL/app/main.qml"
Icon=$ZIEL/paketbote.svg
Categories=Utility;Network;
Keywords=Brief;Post;Paket;DHL;Hermes;DPD;GLS;UPS;Amazon;Sendung;parcel;tracking;
StartupWMClass=qml
DESKTOP
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$ANW" 2>/dev/null || true
# KRunner: Sendungsnummer eintippen → verfolgen; „pakete“ → was unterwegs ist (braucht python3-dbus und python3-gi)
if command -v python3 >/dev/null 2>&1; then
  mkdir -p "$ZIEL/krunner" "${XDG_DATA_HOME:-$HOME/.local/share}/krunner/dbusplugins" "${XDG_DATA_HOME:-$HOME/.local/share}/dbus-1/services"
  cp "$HIER/krunner/paketbote-runner.py" "$ZIEL/krunner/"
  cp "$HIER/krunner/paketbote.desktop" "${XDG_DATA_HOME:-$HOME/.local/share}/krunner/dbusplugins/paketbote.desktop"
  printf '[D-BUS Service]\nName=de.teyro.paketbote.runner\nExec=%s %s\n' "$(command -v python3)" "$ZIEL/krunner/paketbote-runner.py" \
    > "${XDG_DATA_HOME:-$HOME/.local/share}/dbus-1/services/de.teyro.paketbote.runner.service"
  python3 -c "import dbus, gi" 2>/dev/null || echo "Hinweis: Für KRunner python3-dbus und python3-gi installieren."
  # laufenden Runner neu starten, damit die neue Version gilt
  pkill -f paketbote-runner.py 2>/dev/null || true
fi

# Benachrichtigungen (KDE)
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/knotifications6"
cp "$HIER/paketbote.notifyrc" "${XDG_DATA_HOME:-$HOME/.local/share}/knotifications6/paketbote.notifyrc"
echo "App installiert: Startmenü → Post & Pakete"

# Plasma-Widget
if command -v kpackagetool6 >/dev/null 2>&1; then
  TMP="$(mktemp -d)"
  cp -r "$HIER/plasmoid/package" "$TMP/package"
  cp -r "$HIER/gemeinsam" "$TMP/package/contents/ui/gemeinsam"
  if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -q "^de.teyro.paketbote$"; then
    kpackagetool6 -t Plasma/Applet -u "$TMP/package" >/dev/null
  else
    kpackagetool6 -t Plasma/Applet -i "$TMP/package" >/dev/null
  fi
  rm -rf "$TMP"
  echo "Plasma-Widget installiert: Rechtsklick auf den Schreibtisch bzw. das Panel → Widgets hinzufügen → Post & Pakete"
fi
