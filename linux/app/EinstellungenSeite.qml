/*
 * Einstellungen: Home Assistant, Postfach, Anzeige
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../gemeinsam/sprache.js" as S

Kirigami.ScrollablePage {
    id: seite
    required property var ha
    required property var einstellungen
    title: S.t("Einstellungen")

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: S.t("Home Assistant") }
        QQC2.TextField {
            Kirigami.FormData.label: S.t("Adresse")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            text: seite.einstellungen.adresse
            placeholderText: "http://homeassistant.local:8123"
            onEditingFinished: seite.einstellungen.adresse = text.trim()
        }
        Kirigami.PasswordField {
            Kirigami.FormData.label: S.t("Token")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            text: seite.einstellungen.token
            onEditingFinished: seite.einstellungen.token = text.trim()
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            text: S.t("Das Token legst du in Home Assistant an: unten links auf deinen Namen → Sicherheit → Langlebige Zugriffstoken.")
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }
        QQC2.Label {
            Kirigami.FormData.label: S.t("Stand")
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            wrapMode: Text.Wrap
            text: !seite.ha.eingerichtet ? S.t("Noch nicht eingerichtet.")
                  : seite.ha.fehler ? seite.ha.fehler
                  : seite.ha.geladen ? S.t("Verbunden – %1 Postfächer, %2 unterwegs.", seite.ha.konten.length,
                                           seite.ha.sendungen.filter(function (s) { return s.stand !== "zugestellt" && !s.erledigt; }).length) : "…"
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: S.t("Anzeige") }
        QQC2.ComboBox {
            Kirigami.FormData.label: S.t("Postfach")
            visible: seite.ha.konten.length > 1
            model: [S.t("Alle")].concat(seite.ha.konten.map(function (k) { return k.name; }))
            currentIndex: Math.max(0, model.indexOf(seite.einstellungen.konto))
            onActivated: (i) => seite.einstellungen.konto = i === 0 ? "" : model[i]
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: S.t("Zugestellte zeigen (Tage)")
            from: 1; to: 60
            value: seite.einstellungen.tageZugestellt
            onValueModified: seite.einstellungen.tageZugestellt = value
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: S.t("Über") }
        QQC2.Label { Kirigami.FormData.label: S.t("Version"); text: "1.0.0" }
        Kirigami.UrlButton { Kirigami.FormData.label: S.t("Paketbote auf GitHub"); url: "https://github.com/Teyro/Paketbote" }
        Kirigami.UrlButton { Kirigami.FormData.label: S.t("Integration (HACS)"); url: "https://github.com/Teyro/Briefankuendigung-HA" }
    }
}
