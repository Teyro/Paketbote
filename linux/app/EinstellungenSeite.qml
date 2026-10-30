/*
 * Einstellungen: Home Assistant, Postfach, Anzeige
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../gemeinsam/sprache.js" as S
import "../gemeinsam/anbieter.js" as Anbieter

Kirigami.ScrollablePage {
    id: seite
    required property var ha
    required property var einstellungen
    title: S.t("Einstellungen")
    readonly property var aus: { try { return JSON.parse(einstellungen.aus); } catch (e) { return []; } }
    function anbieterSetzen(name, an) {
        var l = aus.filter(function (x) { return x !== name; });
        if (!an) l.push(name);
        einstellungen.aus = JSON.stringify(l);
    }

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

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: S.t("Direkt verfolgen") }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            text: S.t("Post & Pakete fragt die eingeschalteten Anbieter der Reihe nach. Antwortet einer nicht oder kennt die Nummer nicht, springt der nächste ein. DHL und Deutsche Post gehen ohne Schlüssel; für Hermes, DPD, GLS und UPS hilft ein 17TRACK- oder Ship24-Schlüssel.")
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }
        Repeater {
            model: Anbieter.BESCHREIBUNG
            ColumnLayout {
                id: eintrag
                required property var modelData
                readonly property string name: modelData[0]
                readonly property bool aktiv: seite.aus.indexOf(name) < 0
                Kirigami.FormData.label: name
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                spacing: 2
                QQC2.CheckBox {
                    text: eintrag.modelData[1]
                    checked: eintrag.aktiv
                    onToggled: seite.anbieterSetzen(eintrag.name, checked)
                    contentItem: QQC2.Label { leftPadding: parent.indicator.width + parent.spacing; text: parent.text; wrapMode: Text.Wrap }
                }
                Kirigami.PasswordField {
                    Layout.fillWidth: true
                    visible: eintrag.aktiv && ["DHL", "17TRACK", "Ship24"].indexOf(eintrag.name) >= 0
                    placeholderText: S.t("Schlüssel")
                    text: eintrag.name === "DHL" ? seite.einstellungen.dhl : eintrag.name === "17TRACK" ? seite.einstellungen.siebzehn : seite.einstellungen.ship24
                    onEditingFinished: {
                        if (eintrag.name === "DHL") seite.einstellungen.dhl = text.trim();
                        else if (eintrag.name === "17TRACK") seite.einstellungen.siebzehn = text.trim();
                        else seite.einstellungen.ship24 = text.trim();
                    }
                }
                QQC2.TextField {
                    Layout.fillWidth: true
                    visible: eintrag.aktiv && eintrag.name === "UPS"
                    placeholderText: S.t("UPS Client-ID")
                    text: seite.einstellungen.upsId
                    onEditingFinished: seite.einstellungen.upsId = text.trim()
                }
                Kirigami.PasswordField {
                    Layout.fillWidth: true
                    visible: eintrag.aktiv && eintrag.name === "UPS"
                    placeholderText: S.t("UPS Client-Secret")
                    text: seite.einstellungen.upsGeheim
                    onEditingFinished: seite.einstellungen.upsGeheim = text.trim()
                }
            }
        }
        QQC2.CheckBox {
            text: S.t("Öffentliche Seiten fragen (DHL ohne Schlüssel, GLS, DPD)")
            checked: seite.einstellungen.oeffentlich
            onToggled: seite.einstellungen.oeffentlich = checked
        }
        QQC2.CheckBox {
            visible: seite.ha.eingerichtet
            text: S.t("Auch in Home Assistant eintragen")
            checked: seite.einstellungen.auchInHA
            onToggled: seite.einstellungen.auchInHA = checked
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
        QQC2.Label { Kirigami.FormData.label: S.t("Version"); text: "2.1.0" }
        Kirigami.UrlButton { Kirigami.FormData.label: S.t("Post & Pakete auf GitHub"); url: "https://github.com/Teyro/Post-und-Pakete" }
        Kirigami.UrlButton { Kirigami.FormData.label: S.t("Integration (HACS)"); url: "https://github.com/Teyro/Briefankuendigung-HA" }
    }
}
