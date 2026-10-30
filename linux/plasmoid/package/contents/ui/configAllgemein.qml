/*
 * Einstellungen des Widgets: Home Assistant (gemeinsam mit der Paketbote-App), Mitteilungen, Updates
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtCore
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "gemeinsam/sprache.js" as S

KCM.SimpleKCM {
    property alias cfg_mitteilungen: mitteilungen.checked
    property alias cfg_updatesSuchen: updates.checked
    property string cfg_inhalt: "alle"

    Settings {
        id: gemeinsam
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/paketbote.conf"
        property string adresse: ""
        property string token: ""
    }

    Kirigami.FormLayout {
        QQC2.TextField {
            Kirigami.FormData.label: S.t("Adresse")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            text: gemeinsam.adresse
            placeholderText: "http://homeassistant.local:8123"
            onEditingFinished: gemeinsam.adresse = text.trim()
        }
        Kirigami.PasswordField {
            Kirigami.FormData.label: S.t("Token")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            text: gemeinsam.token
            onEditingFinished: gemeinsam.token = text.trim()
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            text: S.t("Das Token legst du in Home Assistant an: unten links auf deinen Namen → Sicherheit → Langlebige Zugriffstoken.")
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }
        Item { Kirigami.FormData.isSection: true }
        QQC2.ComboBox {
            Kirigami.FormData.label: S.t("Zeigen")
            model: [S.t("Briefe und Pakete"), S.t("Nur Briefe"), S.t("Nur Pakete")]
            currentIndex: Math.max(0, ["alle", "briefe", "pakete"].indexOf(cfg_inhalt))
            onActivated: (i) => cfg_inhalt = ["alle", "briefe", "pakete"][i]
        }
        QQC2.CheckBox { id: mitteilungen; text: S.t("Mitteilungen bei neuem Stand") }
        QQC2.CheckBox { id: updates; text: S.t("Nach Updates suchen") }
    }
}
