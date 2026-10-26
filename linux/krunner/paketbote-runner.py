#!/usr/bin/env python3
"""KRunner-Anschluss für Paketbote (D-Bus): Sendungsnummer eintippen → verfolgen; „pakete“ → Sendungen von heute und unterwegs.

Mit Home Assistant (Einstellungen der Paketbote-App in ~/.config/paketbote.conf) wird die Nummer dort eingetragen,
sonst öffnet sich die Paketbote-App mit der Nummer. Braucht python3-dbus und python3-gi (bei KDE meist schon da).
SPDX-License-Identifier: GPL-3.0-or-later
"""

import configparser
import json
import os
import re
import shlex
import subprocess
import urllib.request

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

DIENST = "de.teyro.paketbote.runner"
PFAD = "/runner"
SCHNITTSTELLE = "org.kde.krunner1"
NAMEN = {"dhl": "DHL", "hermes": "Hermes", "dpd": "DPD", "gls": "GLS", "ups": "UPS", "amazon": "Amazon"}
DE = os.environ.get("LANG", "de").startswith("de")


def t(de: str, en: str) -> str:
    return de if DE else en


def nummer_in(text: str) -> str:
    m = re.search(r"TBA\d{9,14}|\d{3}-\d{7}-\d{7}|JJD\d{12,20}|1Z[0-9A-Z]{16}|H[0-9A-Z]{19}|\d{11,20}", text.upper())
    return m.group(0) if m else ""


def dienst_von_nummer(n: str) -> str:
    if re.fullmatch(r"TBA\d{9,14}|\d{3}-\d{7}-\d{7}", n):
        return "amazon"
    if re.fullmatch(r"JJD\d{12,20}|00\d{18}|\d{20}|\d{12}", n):
        return "dhl"
    if re.fullmatch(r"H[0-9A-Z]{19}", n):
        return "hermes"
    if re.fullmatch(r"1Z[0-9A-Z]{16}", n):
        return "ups"
    return ""


def einstellungen() -> dict:
    p = configparser.ConfigParser(interpolation=None)
    p.read(os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "paketbote.conf"))
    g = p["General"] if "General" in p else {}
    adresse = (g.get("adresse", "") or "").strip().strip('"').rstrip("/")
    if adresse and "://" not in adresse:
        adresse = "http://" + adresse
    return {"adresse": adresse, "token": (g.get("token", "") or "").strip().strip('"'), "konto": (g.get("konto", "") or "").strip().strip('"')}


def ha(methode: str, pfad: str, koerper: dict | None = None):
    e = einstellungen()
    if not e["adresse"] or not e["token"]:
        return None
    r = urllib.request.Request(e["adresse"] + pfad, method=methode, data=json.dumps(koerper).encode() if koerper is not None else None,
                               headers={"Authorization": "Bearer " + e["token"], "Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=8) as a:
        return json.loads(a.read() or b"null")


def melden(titel: str, text: str) -> None:
    subprocess.Popen(["notify-send", "-a", "Paketbote", "-i", "package-x-generic", titel, text])


def app_oeffnen(*argumente: str) -> None:
    """Paketbote-App starten (Befehl aus dem Startmenü-Eintrag)"""
    datei = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")), "applications", "de.teyro.paketbote.desktop")
    befehl = ""
    try:
        with open(datei, encoding="utf-8") as f:
            befehl = next((z[5:].strip() for z in f if z.startswith("Exec=")), "")
    except OSError:
        pass
    if befehl:
        subprocess.Popen(shlex.split(befehl) + ["--", *argumente])


class Runner(dbus.service.Object):
    def __init__(self):
        dbus.service.Object.__init__(self, dbus.service.BusName(DIENST, dbus.SessionBus()), PFAD)
        self.zwischen: dict[str, dict] = {}

    @dbus.service.method(SCHNITTSTELLE, in_signature="s", out_signature="a(sssida{sv})")
    def Match(self, anfrage: str):
        q = anfrage.strip()
        treffer = []
        n = nummer_in(q)
        if n and len(q) <= len(n) + 30:
            d = dienst_von_nummer(n)
            treffer.append((f"neu|{n}|{d}", t(f"Sendung {n} verfolgen", f"Track shipment {n}"), "package-x-generic", 100, 0.9,
                            {"subtext": t("Paketbote", "Paketbote") + (f" · {NAMEN[d]}" if d else "")}))
        if q.lower() in ("paket", "pakete", "paketbote", "parcel", "parcels", "sendungen"):
            try:
                daten = ha("GET", "/api/briefankuendigung/briefe") or {}
            except Exception:  # noqa: BLE001
                daten = {}
            offen = [b for b in daten.get("briefe", []) if b.get("art") == "paket" and not b.get("erledigt") and b.get("stand") != "zugestellt"]
            for b in offen[:8]:
                stand = {"heute": t("kommt heute", "arrives today"), "abholbereit": t("zur Abholung bereit", "ready for pickup")}.get(
                    b.get("stand"), (t("voraussichtlich ", "expected ") + b["erwartet"]) if b.get("erwartet") else t("unterwegs", "on the way"))
                self.zwischen[b["id"]] = b
                treffer.append((f"zeigen|{b['id']}", b.get("name") or b.get("absender") or b.get("sendung") or t("Paket", "Parcel"),
                                "package-x-generic", 70, 0.8 if b.get("stand") in ("heute", "abholbereit") else 0.6,
                                {"subtext": f"{NAMEN.get(b.get('dienst') or 'dhl', '')} · {stand}"}))
            if not offen:
                treffer.append(("app|", t("Paketbote öffnen", "Open Paketbote"), "package-x-generic", 50, 0.5,
                                {"subtext": t("Keine Pakete unterwegs", "No parcels on the way") if daten else ""}))
        return treffer

    @dbus.service.method(SCHNITTSTELLE, out_signature="a(sss)")
    def Actions(self):
        return []

    @dbus.service.method(SCHNITTSTELLE, in_signature="ss")
    def Run(self, kennung: str, aktion: str):
        art, _, rest = kennung.partition("|")
        if art == "neu":
            n, _, d = rest.partition("|")
            try:
                if ha("POST", "/api/briefankuendigung/sendung", {"nummer": n, "dienst": d, "name": "", "konto": einstellungen()["konto"]}) is not None:
                    melden(t("📦 Hinzugefügt", "📦 Added"), t(f"Sendung {n} wird verfolgt.", f"Tracking shipment {n}."))
                    return
            except Exception:  # noqa: BLE001 – ohne Home Assistant (oder bei Fehler) die App öffnen
                pass
            app_oeffnen("--neu", n)
        elif art == "zeigen":
            b = self.zwischen.get(rest) or {}
            if b.get("verfolgen", "").startswith("https://"):
                subprocess.Popen(["xdg-open", b["verfolgen"]])
            else:
                app_oeffnen()
        else:
            app_oeffnen()


if __name__ == "__main__":
    DBusGMainLoop(set_as_default=True)
    Runner()
    GLib.MainLoop().run()
