# Paketbote

**Paketverfolgung für iPhone, iPad, Mac und Linux – DHL, Hermes, DPD, GLS, UPS und Amazon.**
Wie die App *Parcel*, nur ohne fremden Server: Die Zentrale ist dein Home Assistant mit der Integration
[Briefankündigung](https://github.com/Teyro/Briefankuendigung-HA) (ab 1.5). Sie liest die Versandmails der
Dienste, fragt auf Wunsch DHL und 17TRACK nach dem aktuellen Stand und hält alle Geräte auf demselben Stand.

*English: see [README.md](README.md)*

## Was Paketbote kann

- **Alle Sendungen auf einen Blick:** Heute · Unterwegs · Zugestellt – sortiert nach voraussichtlicher Zustellung
  („kommt morgen, 10:00–13:00“, „voraussichtlich Fr 30.10.“, „zur Abholung bereit“, „überfällig seit …“)
- **Verlauf jeder Sendung** mit Stationen und – auf iPhone und Mac – einer **Karte** der Orte
- **Logos in den Farben der Dienste**, Fortschritt in vier Schritten (angekündigt → unterwegs → in Zustellung → zugestellt)
- **Sendung hinzufügen** per Nummer (auch aus der Zwischenablage), der Dienst wird meist erkannt; **umbenennen**,
  „Angekommen“ abhaken (gilt auf allen Geräten), eigene Sendungen entfernen, beim Dienst verfolgen
- **Mehrere Amazon-Konten:** an jedem Paket steht, für wen es ist (Kundenkonten in der Integration)
- **Mitteilungen** bei „kommt heute“, „zur Abholung bereit“, „zugestellt“ und Problemen
- **Widgets:** iPhone (Home- und Sperrbildschirm), Mac (Schreibtisch), Plasma (Panel und Kachel)
- **Siri & Kurzbefehle:** „Welche Pakete kommen heute mit Paketbote?“, „Sendung mit Paketbote verfolgen“
- Deutsch und Englisch, hell und dunkel, Updates (Mac und Linux mit einem Klick)

## Bestandteile

| | |
|---|---|
| **iPhone / iPad** | SwiftUI-App mit Widgets, Hintergrundabruf und Siri – als IPA zum Installieren über **Signulous** (oder eine eigene Signatur) |
| **Mac** | gleiche App für macOS 14+: Fenster mit Liste und Sendung, Symbol in der Menüleiste, Schreibtisch-Widgets |
| **Linux** | Kirigami-App (Startmenü) und **Plasma-6-Widget** mit Zahl im Panel – beide teilen sich die Einstellungen |

## Voraussetzung: Home Assistant

1. Integration **Briefankündigung** über HACS installieren (ab **1.5**) und dein Postfach eintragen.
2. Unter *Konfigurieren*: die **Paketdienste** wählen; optional
   - **17TRACK-Schlüssel** (api.17track.net, kostenlos: einmalig 200 Sendungen) für den Live-Stand von Hermes, DPD, GLS, UPS,
   - **DHL-API-Schlüssel** (developer.dhl.com, kostenlos) für DHL live,
   - **Mitteilungen an** die Home-Assistant-App deines iPhones – die zuverlässigsten Push-Mitteilungen.
3. Ein **langlebiges Zugriffstoken** anlegen (unten links auf deinen Namen → Sicherheit).

Amazon, Hermes und DPD haben keine offene Schnittstelle für Privatkunden. Paketbote meldet sich dort
bewusst **nicht** mit deinem Konto an – die Versandmails und 17TRACK genügen.

## Installieren

**iPhone/iPad:** `Paketbote-iOS-x.y.z.ipa` aus den [Releases](https://github.com/Teyro/Paketbote/releases) in Signulous
hochladen und installieren. Beim ersten Start Adresse und Token eintragen; Widgets wie gewohnt hinzufügen.
Neue Versionen zeigt die App oben als Hinweis.

**Mac:** `Paketbote-macOS-x.y.z.zip` laden, `Paketbote.app` in „Programme“ ziehen. Beim ersten Start mit
Rechtsklick → Öffnen (die App ist nicht notariell beglaubigt). Updates: Menü *Paketbote → Nach Updates suchen*.

**Linux:** `paketbote-linux-x.y.z.tar.gz` entpacken und `sh paketbote/installieren.sh` ausführen (ohne Root).
Danach steht *Paketbote* im Startmenü und – unter Plasma 6 – in der Widget-Auswahl. Braucht Qt 6 und Kirigami
(bei KDE Plasma schon dabei). Updates installiert das Plasma-Widget auf Knopfdruck.

## Entwickeln

- `apple/`: `swift test` prüft den Kern; `apple/scripts/baue.sh` baut Mac-App und IPA (Xcode + XcodeGen)
- `linux/`: `node linux/test/logik-test.mjs`; Start ohne Installation: `qml6 -a widget linux/app/main.qml`
- `test/ha-mock.mjs`: nachgebautes Home Assistant für Tests und Bildschirmfotos
- Texte: deutsche Schlüssel, englisch in `i18n/en.json` (`node werkzeuge/texte.mjs`, dann `node werkzeuge/baue-uebersetzungen.mjs`)

Lizenz: GPL-3.0-or-later
