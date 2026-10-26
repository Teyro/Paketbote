# Paketbote

**Parcel tracking for iPhone, iPad, Mac and Linux – DHL, Hermes, DPD, GLS, UPS and Amazon.**
Like the app *Parcel*, but without someone else’s server: the hub is your Home Assistant with the integration
[Briefankündigung](https://github.com/Teyro/Briefankuendigung-HA) (1.5 or later). It reads the carriers’ shipping
mails, optionally asks DHL and 17TRACK for the live status, and keeps all your devices in sync.

*Deutsch: siehe [README.de.md](README.de.md)*

## Features

- **All shipments at a glance:** Today · On the way · Delivered – sorted by expected delivery
  (“arrives tomorrow, 10:00–13:00”, “expected Fri 30.10.”, “ready for pickup”, “overdue since …”)
- **History of each shipment** with its stops and – on iPhone and Mac – a **map**
- **Carrier logos in their colours**, progress in four steps (announced → on the way → out for delivery → delivered)
- **Add a shipment** by number (also from the clipboard) – the carrier is usually detected; **rename**, mark as
  arrived (synced to all devices), remove your own shipments, open the carrier’s tracking page
- **Several Amazon accounts:** each parcel shows whose it is (customer accounts in the integration)
- **Notifications** for “arriving today”, “ready for pickup”, “delivered” and problems
- **Widgets:** iPhone (home and lock screen), Mac (desktop), Plasma (panel and desktop tile)
- **Siri & Shortcuts:** “Which parcels arrive today with Paketbote?”, “Track a shipment with Paketbote”
- German and English, light and dark, updates (one click on Mac and Linux)

## Parts

| | |
|---|---|
| **iPhone / iPad** | SwiftUI app with widgets, background refresh and Siri – as an IPA to install via **Signulous** (or your own signing) |
| **Mac** | the same app for macOS 14+: window with list and details, menu bar icon, desktop widgets |
| **Linux** | Kirigami app (application menu) and a **Plasma 6 widget** with a count in the panel – both share their settings |

## Requirement: Home Assistant

1. Install the **Briefankündigung** integration via HACS (**1.5** or later) and add your mailbox.
2. Under *Configure*: choose the **carriers**; optionally
   - a **17TRACK key** (api.17track.net, free: a one-time 200 shipments) for live status of Hermes, DPD, GLS, UPS,
   - a **DHL API key** (developer.dhl.com, free) for DHL live,
   - **Send notifications to** the Home Assistant app on your iPhone – the most reliable push notifications.
3. Create a **long-lived access token** (your name at the bottom left → Security).

Amazon, Hermes and DPD have no open API for consumers. Paketbote deliberately does **not** log in with your
account there – the shipping mails and 17TRACK are enough.

## Installation

**iPhone/iPad:** upload `Paketbote-iOS-x.y.z.ipa` from the [releases](https://github.com/Teyro/Paketbote/releases) to
Signulous and install it. Enter address and token on first start; add widgets as usual. The app shows new versions at the top.

**Mac:** download `Paketbote-macOS-x.y.z.zip` and move `Paketbote.app` to Applications. First start: right-click → Open
(the app is not notarised). Updates: menu *Paketbote → Check for updates*.

**Linux:** extract `paketbote-linux-x.y.z.tar.gz` and run `sh paketbote/installieren.sh` (no root needed). Then
*Paketbote* is in the application menu and – on Plasma 6 – in the widget list. Needs Qt 6 and Kirigami
(included with KDE Plasma). The Plasma widget installs updates with one click.

## Development

- `apple/`: `swift test` checks the core; `apple/scripts/baue.sh` builds the Mac app and the IPA (Xcode + XcodeGen)
- `linux/`: `node linux/test/logik-test.mjs`; run without installing: `qml6 -a widget linux/app/main.qml`
- `test/ha-mock.mjs`: a fake Home Assistant for tests and screenshots
- Texts: German keys, English in `i18n/en.json` (`node werkzeuge/texte.mjs`, then `node werkzeuge/baue-uebersetzungen.mjs`)

License: GPL-3.0-or-later
