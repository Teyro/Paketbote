/*
 * Liste: Heute · Unterwegs · Zugestellt
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
    property var gruppen
    property double jetzt: Date.now()
    property string auswahl: ""
    signal gewaehlt(string id)
    signal hinzufuegen()
    signal einstellungen()

    title: Logik.kopfTitel(gruppen.aktiv)
    supportsRefreshing: true
    refreshing: ha.laedt
    onRefreshingChanged: if (refreshing && !ha.laedt) ha.laden()

    actions: [
        Kirigami.Action {
            text: S.t("Sendung hinzufügen")
            icon.name: "list-add"
            shortcut: StandardKey.New
            enabled: seite.ha.eingerichtet
            onTriggered: seite.hinzufuegen()
        },
        Kirigami.Action {
            text: S.t("Neu laden")
            icon.name: "view-refresh"
            displayHint: Kirigami.DisplayHint.IconOnly
            shortcut: StandardKey.Refresh
            onTriggered: seite.ha.laden()
        },
        Kirigami.Action {
            text: S.t("Postfach jetzt lesen")
            icon.name: "mail-receive"
            displayHint: Kirigami.DisplayHint.AlwaysHide
            onTriggered: seite.ha.jetztNachsehen()
        },
        Kirigami.Action {
            text: S.t("Einstellungen …")
            icon.name: "configure"
            displayHint: Kirigami.DisplayHint.AlwaysHide
            onTriggered: seite.einstellungen()
        }
    ]

    header: QQC2.Control {
        visible: !seite.ha.eingerichtet || seite.ha.fehler !== ""
        padding: Kirigami.Units.smallSpacing
        contentItem: Kirigami.InlineMessage {
            visible: true
            type: seite.ha.eingerichtet ? Kirigami.MessageType.Error : Kirigami.MessageType.Information
            text: seite.ha.eingerichtet ? seite.ha.fehler
                  : S.t("Paketbote zeigt die Sendungen der Home-Assistant-Integration „Briefankündigung“ (HACS). Adresse und Token eintragen.")
            actions: Kirigami.Action {
                text: seite.ha.eingerichtet ? S.t("Neu laden") : S.t("Einrichten …")
                onTriggered: seite.ha.eingerichtet ? seite.ha.laden() : seite.einstellungen()
            }
        }
    }

    ListView {
        id: liste
        model: {
            var m = [];
            seite.gruppen.heute.forEach(function (s) { m.push({ abschnitt: S.t("Heute"), s: s }); });
            seite.gruppen.unterwegs.forEach(function (s) { m.push({ abschnitt: S.t("Unterwegs"), s: s }); });
            seite.gruppen.zugestellt.forEach(function (s) { m.push({ abschnitt: S.t("Zugestellt"), s: s }); });
            return m;
        }
        section.property: "abschnitt"
        section.delegate: Kirigami.ListSectionHeader {
            required property string section
            width: ListView.view.width
            text: section
        }
        delegate: SendungsZeile {
            required property var modelData
            sendung: modelData.s
            jetzt: seite.jetzt
            mitKonto: seite.ha.mehrereKonten
            highlighted: modelData.s.id === seite.auswahl
            onClicked: seite.gewaehlt(modelData.s.id)
        }

        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 4
            visible: seite.ha.eingerichtet && seite.ha.geladen && liste.count === 0
            icon.name: "package-x-generic"
            text: S.t("Keine Pakete unterwegs")
            explanation: S.t("Versandmails von DHL, Hermes, DPD, GLS, UPS und Amazon erscheinen hier – oder eine Sendung mit ＋ hinzufügen.")
            helpfulAction: Kirigami.Action {
                text: S.t("Sendung hinzufügen")
                icon.name: "list-add"
                onTriggered: seite.hinzufuegen()
            }
        }
        QQC2.BusyIndicator {
            anchors.centerIn: parent
            visible: seite.ha.eingerichtet && !seite.ha.geladen && seite.ha.fehler === ""
        }
    }
}
