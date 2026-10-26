/*
 * Eine Sendung: Stand, Verlauf, Aktionen (beim Dienst verfolgen, angekommen, umbenennen, entfernen)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../gemeinsam"
import "../gemeinsam/logik.js" as Logik
import "../gemeinsam/sprache.js" as S

Kirigami.ScrollablePage {
    id: seite
    required property var ha
    property var sendung
    property double jetzt: Date.now()

    title: sendung ? Logik.titel(sendung) : ""
    onSendungChanged: if (sendung && (sendung.quelle === "direkt" || !sendung.ereignisse.length)) ha.einmalAbfragen(sendung)

    actions: [
        Kirigami.Action {
            text: S.t("Beim Dienst")
            icon.name: "internet-web-browser"
            visible: !!seite.sendung && Logik.verfolgenAdresse(seite.sendung) !== ""
            onTriggered: Qt.openUrlExternally(Logik.verfolgenAdresse(seite.sendung))
        },
        Kirigami.Action {
            text: seite.sendung && seite.sendung.erledigt ? S.t("Doch nicht angekommen") : S.t("Angekommen")
            icon.name: seite.sendung && seite.sendung.erledigt ? "edit-undo" : "dialog-ok-apply"
            visible: !!seite.sendung && (seite.sendung.erledigt || !Logik.fertig(seite.sendung))
            onTriggered: seite.ha.erledigt(seite.sendung.id, !seite.sendung.erledigt)
        },
        Kirigami.Action {
            text: S.t("Umbenennen")
            icon.name: "edit-rename"
            displayHint: Kirigami.DisplayHint.AlwaysHide
            onTriggered: { neuerName.text = seite.sendung.name; umbenennen.open(); }
        },
        Kirigami.Action {
            text: S.t("Nummer kopieren")
            icon.name: "edit-copy"
            displayHint: Kirigami.DisplayHint.AlwaysHide
            visible: !!seite.sendung && !!seite.sendung.nummer
            onTriggered: { kopie.text = seite.sendung.nummer; kopie.selectAll(); kopie.copy(); applicationWindow().showPassiveNotification(S.t("Nummer kopiert")); }
        },
        Kirigami.Action {
            text: S.t("Entfernen")
            icon.name: "edit-delete"
            displayHint: Kirigami.DisplayHint.AlwaysHide
            visible: !!seite.sendung && seite.sendung.manuell
            onTriggered: { seite.ha.entfernen(seite.sendung.id); applicationWindow().pageStack.pop(); }
        }
    ]

    QQC2.TextField { id: kopie; visible: false }

    DetailInhalt {
        visible: !!seite.sendung
        sendung: seite.sendung || { ereignisse: [], dienst: "dhl" }
        jetzt: seite.jetzt
        mitKonto: seite.ha.mehrereKonten
        anbieterFehler: seite.ha.anbieterFehler
    }

    Kirigami.PromptDialog {
        id: umbenennen
        title: S.t("Umbenennen")
        subtitle: S.t("Leer lassen, um wieder den Absender zu zeigen.")
        standardButtons: Kirigami.Dialog.Save | Kirigami.Dialog.Cancel
        QQC2.TextField {
            id: neuerName
            placeholderText: S.t("Name")
            onAccepted: umbenennen.accept()
        }
        onAccepted: seite.ha.umbenennen(seite.sendung.id, neuerName.text.trim())
    }
}
