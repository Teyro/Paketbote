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
    property var briefGruppen: ({ heute: [], unterwegs: [], angekommen: [], offen: [] })
    /// "alle" | "briefe" | "pakete"
    property string bereich: "alle"
    signal bereichGewaehlt(string b)
    property double jetzt: Date.now()
    property string auswahl: ""
    signal gewaehlt(string id)
    signal hinzufuegen()
    signal einstellungen()

    readonly property bool mitBriefen: bereich !== "pakete"
    readonly property bool mitPaketen: bereich !== "briefe"
    title: Logik.postTitel(mitBriefen ? briefGruppen.offen : [], mitPaketen ? gruppen.aktiv : [])
    supportsRefreshing: true
    refreshing: ha.laedt
    onRefreshingChanged: if (refreshing && !ha.laedt) ha.laden()

    actions: [
        Kirigami.Action {
            text: S.t("Sendung hinzufügen")
            icon.name: "list-add"
            shortcut: StandardKey.New
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

    header: ColumnLayout {
        spacing: 0
        QQC2.TabBar {
            Layout.fillWidth: true
            visible: seite.ha.eingerichtet
            currentIndex: ["alle", "briefe", "pakete"].indexOf(seite.bereich)
            QQC2.TabButton { text: S.t("Alles"); onClicked: seite.bereichGewaehlt("alle") }
            QQC2.TabButton {
                text: seite.briefGruppen.offen.length ? S.t("Briefe (%1)", seite.briefGruppen.offen.length) : S.t("Briefe")
                onClicked: seite.bereichGewaehlt("briefe")
            }
            QQC2.TabButton {
                text: seite.gruppen.aktiv.length ? S.t("Pakete (%1)", seite.gruppen.aktiv.length) : S.t("Pakete")
                onClicked: seite.bereichGewaehlt("pakete")
            }
        }
        QQC2.Control {
        Layout.fillWidth: true
        visible: !seite.ha.bereit || seite.ha.fehler !== ""
        padding: Kirigami.Units.smallSpacing
        contentItem: Kirigami.InlineMessage {
            visible: true
            type: seite.ha.bereit ? Kirigami.MessageType.Error : Kirigami.MessageType.Information
            text: seite.ha.bereit ? seite.ha.fehler
                  : S.t("Einfach eine Sendungsnummer eintragen – oder mit Home Assistant verbinden: dann kommen die angekündigten Briefe und die Pakete aus deinen Versandmails dazu.")
            actions: [
                Kirigami.Action {
                    visible: !seite.ha.bereit
                    text: S.t("Sendung hinzufügen")
                    icon.name: "list-add"
                    onTriggered: seite.hinzufuegen()
                },
                Kirigami.Action {
                    text: seite.ha.bereit ? S.t("Neu laden") : S.t("Home Assistant …")
                    onTriggered: seite.ha.bereit ? seite.ha.laden() : seite.einstellungen()
                }
            ]
        }
        }
    }

    ListView {
        id: liste
        model: {
            var m = [], b = seite.mitBriefen ? seite.briefGruppen : { heute: [], unterwegs: [], angekommen: [] };
            var g = seite.mitPaketen ? seite.gruppen : { heute: [], unterwegs: [], zugestellt: [] };
            b.heute.forEach(function (x) { m.push({ abschnitt: S.t("Heute"), b: x }); });
            g.heute.forEach(function (s) { m.push({ abschnitt: S.t("Heute"), s: s }); });
            b.unterwegs.forEach(function (x) { m.push({ abschnitt: S.t("Unterwegs"), b: x }); });
            g.unterwegs.forEach(function (s) { m.push({ abschnitt: S.t("Unterwegs"), s: s }); });
            b.angekommen.slice(0, 10).forEach(function (x) { m.push({ abschnitt: S.t("Angekommen"), b: x }); });
            g.zugestellt.forEach(function (s) { m.push({ abschnitt: S.t("Angekommen"), s: s }); });
            return m;
        }
        section.property: "abschnitt"
        section.delegate: Kirigami.ListSectionHeader {
            required property string section
            width: ListView.view.width
            text: section
        }
        delegate: Loader {
            id: eintrag
            required property var modelData
            width: ListView.view.width
            sourceComponent: modelData.b ? briefKomponente : paketKomponente
            Component {
                id: paketKomponente
                SendungsZeile {
                    sendung: eintrag.modelData.s
                    jetzt: seite.jetzt
                    mitKonto: seite.ha.mehrereKonten
                    highlighted: eintrag.modelData.s.id === seite.auswahl
                    onClicked: seite.gewaehlt(eintrag.modelData.s.id)
                }
            }
            Component {
                id: briefKomponente
                BriefZeile {
                    brief: eintrag.modelData.b
                    bild: seite.ha.bilder[eintrag.modelData.b.id] || ""
                    jetzt: seite.jetzt
                    mitKonto: seite.ha.mehrereKonten
                    highlighted: eintrag.modelData.b.id === seite.auswahl
                    onClicked: seite.gewaehlt(eintrag.modelData.b.id)
                }
            }
        }

        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 4
            visible: seite.ha.bereit && seite.ha.geladen && liste.count === 0
            icon.name: seite.bereich === "briefe" ? "mail-message" : "package-x-generic"
            text: seite.bereich === "briefe" ? S.t("Keine Briefe angekündigt") : seite.bereich === "pakete" ? S.t("Keine Pakete unterwegs") : S.t("Keine Post unterwegs")
            explanation: seite.ha.eingerichtet ? S.t("Versandmails von DHL, Hermes, DPD, GLS, UPS und Amazon erscheinen hier – oder eine Sendung mit ＋ hinzufügen.")
                         : S.t("Sendungsnummer mit ＋ eintragen – Post & Pakete holt Stand, Verlauf und Karte.")
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
