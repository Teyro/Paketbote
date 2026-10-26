/*
 * Sendung von Hand verfolgen: Nummer (auch aus der Zwischenablage), Paketdienst (meist erkannt), Name
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "logik.js" as Logik
import "anbieter.js" as Anbieter
import "sprache.js" as S

ColumnLayout {
    id: formular
    required property var ha
    signal fertig()

    property string fehler: ""
    property bool laeuft: false
    readonly property var dienste: [""].concat(Logik.ALLE)
    readonly property string erkannt: Logik.dienstVonNummer(nummer.text)
    readonly property string gewaehlt: dienst.currentIndex > 0 ? dienste[dienst.currentIndex] : erkannt
    readonly property bool bereit: nummer.text.trim() !== "" && gewaehlt !== "" && !laeuft

    /// Nummer beim nächsten Öffnen (z. B. aus KRunner)
    property string vorgabe: ""
    function zuruecksetzen() { nummer.text = vorgabe; vorgabe = ""; name.text = ""; dienst.currentIndex = 0; ruecksendung.checked = false; fehler = ""; nummer.forceActiveFocus(); }
    function senden() {
        if (!bereit) return;
        laeuft = true;
        fehler = "";
        ha.hinzufuegen(nummer.text.trim(), gewaehlt, name.text.trim(), function (text) {
            laeuft = false;
            fehler = text;
            if (!text) { zuruecksetzen(); formular.fertig(); }
        }, ruecksendung.checked);
    }
    /// Nummer aus der Zwischenablage holen (über ein unsichtbares Textfeld)
    function einfuegen() {
        ablage.text = "";
        ablage.paste();
        var n = Logik.nummerIn(ablage.text);
        if (n) nummer.text = n;
    }

    spacing: Kirigami.Units.smallSpacing
    QQC2.TextField { id: ablage; visible: false }

    Kirigami.FormLayout {
        Layout.fillWidth: true
        RowLayout {
            Kirigami.FormData.label: S.t("Sendungsnummer")
            QQC2.TextField {
                id: nummer
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 14
                placeholderText: S.t("Sendungs- oder Bestellnummer")
                onAccepted: formular.senden()
            }
            QQC2.ToolButton {
                icon.name: "edit-paste"
                text: S.t("Einfügen")
                display: QQC2.AbstractButton.IconOnly
                onClicked: formular.einfuegen()
                QQC2.ToolTip.text: S.t("Nummer aus der Zwischenablage")
                QQC2.ToolTip.visible: hovered
            }
        }
        QQC2.ComboBox {
            id: dienst
            Kirigami.FormData.label: S.t("Paketdienst")
            model: [formular.erkannt ? S.t("Automatisch (%1)", Logik.dienst(formular.erkannt).name) : S.t("Bitte wählen")]
                   .concat(Logik.ALLE.map(function (d) { return Logik.dienst(d).name; }))
        }
        QQC2.TextField {
            id: name
            Kirigami.FormData.label: S.t("Name")
            Layout.fillWidth: true
            placeholderText: S.t("Name, z. B. „Neue Schuhe“ (optional)")
            onAccepted: formular.senden()
        }
        QQC2.CheckBox {
            id: ruecksendung
            Kirigami.FormData.label: S.t("Rücksendung")
        }
    }
    QQC2.Label {
        Layout.fillWidth: true
        visible: text !== ""
        text: formular.fehler || (nummer.text.trim() !== "" && formular.gewaehlt === "" ? S.t("Die Nummer passt zu mehreren Diensten – bitte den Paketdienst wählen.") : "")
        color: formular.fehler ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
        wrapMode: Text.Wrap
    }
    QQC2.Label {
        Layout.fillWidth: true
        text: formular.gewaehlt && Anbieter.namen(formular.ha.schluessel, formular.gewaehlt).length
              ? S.t("Abfrage über %1.", Anbieter.namen(formular.ha.schluessel, formular.gewaehlt).join(" → "))
              : formular.gewaehlt ? S.t("Für %1 ist noch kein Anbieter eingerichtet (Einstellungen → Direkt verfolgen).", Logik.dienst(formular.gewaehlt).name)
              : S.t("Paketbote fragt selbst bei den Anbietern nach – auch ohne Home Assistant.")
        font: Kirigami.Theme.smallFont
        color: Kirigami.Theme.disabledTextColor
        wrapMode: Text.Wrap
    }
}
