/*
 * Paketbote für Plasma 6: Symbol mit Zahl im Panel, Liste der Sendungen im Popup (bzw. als Kachel).
 * Daten über Home Assistant (Integration „Briefankündigung“); Zugang gemeinsam mit der Paketbote-App.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtCore
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import "gemeinsam"
import "gemeinsam/logik.js" as Logik
import "gemeinsam/sprache.js" as S

PlasmoidItem {
    id: root

    Settings {
        id: gemeinsam
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/paketbote.conf"
        property string adresse: ""
        property string token: ""
        property string konto: ""
        property int tageZugestellt: 14
        property string direkt: "[]"
        property string dhl: ""
        property string upsId: ""
        property string upsGeheim: ""
        property string siebzehn: ""
        property string ship24: ""
        property bool oeffentlich: true
        // abgeschaltete Anbieter (JSON-Liste von Namen)
        property string aus: "[]"
        property bool auchInHA: true
    }

    property double jetzt: Date.now()
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.jetzt = Date.now() }

    Verbindung {
        id: verbindung
        adresse: gemeinsam.adresse
        token: gemeinsam.token
        konto: gemeinsam.konto
        auchInHA: gemeinsam.auchInHA
        schluessel: ({ dhl: gemeinsam.dhl, upsId: gemeinsam.upsId, upsGeheim: gemeinsam.upsGeheim,
                       siebzehn: gemeinsam.siebzehn, ship24: gemeinsam.ship24, oeffentlich: gemeinsam.oeffentlich,
                       aus: (function () { try { return JSON.parse(gemeinsam.aus); } catch (e) { return []; } })() })
        direkt: { try { return JSON.parse(gemeinsam.direkt); } catch (e) { return []; } }
        onDirektGeaendert: (liste) => gemeinsam.direkt = JSON.stringify(liste)
        Component.onCompleted: laden()
        onNeuerStand: (titel, text, id) => { if (Plasmoid.configuration.mitteilungen) root.melden(titel, text); }
    }

    readonly property var gruppen: Logik.gruppen(verbindung.sendungen, jetzt, gemeinsam.tageZugestellt)

    // Mitteilungen und Update über die Kommandozeile
    P5Support.DataSource {
        id: shell
        engine: "executable"
        connectedSources: []
        onNewData: (quelle, daten) => {
            disconnectSource(quelle);
            if (quelle.indexOf("paketbote-update") >= 0) updater.fertig(daten["exit code"], daten.stderr || "");
        }
    }
    function sh(text) { return "'" + String(text).replace(/'/g, "'\\''") + "'"; }
    function melden(titel, text) {
        shell.connectSource("notify-send -a Paketbote -i package-x-generic " + sh(titel) + " " + sh(text));
    }

    // Updates: neueste Version auf GitHub; Installation lädt das Linux-Paket und führt installieren.sh aus
    QtObject {
        id: updater
        property string neu: ""
        property string datei: ""
        property bool laeuft: false
        property string fehler: ""
        function pruefen() {
            var x = new XMLHttpRequest();
            x.open("GET", "https://api.github.com/repos/Teyro/Paketbote/releases/latest");
            x.onreadystatechange = function () {
                if (x.readyState !== XMLHttpRequest.DONE || x.status !== 200) return;
                var j = JSON.parse(x.responseText), v = String(j.tag_name || "").replace(/^v/, "");
                var a = (j.assets || []).find(function (a) { return /^paketbote-linux-[\d.]+\.tar\.gz$/.test(a.name)
                    && String(a.browser_download_url).indexOf("https://github.com/Teyro/Paketbote/releases/download/") === 0; });
                if (a && neuer(v, Plasmoid.metaData.version)) { neu = v; datei = a.browser_download_url; }
            };
            x.send();
        }
        function neuer(a, b) {
            var x = a.split(".").map(Number), y = b.split(".").map(Number);
            for (var i = 0; i < 3; i++) if ((x[i] || 0) !== (y[i] || 0)) return (x[i] || 0) > (y[i] || 0);
            return false;
        }
        function installieren() {
            if (!datei) return;
            laeuft = true;
            fehler = "";
            shell.connectSource("sh -c " + sh("d=$(mktemp -d) && cd \"$d\" && curl -fsSL " + sh(datei) + " | tar xz && sh ./paketbote/installieren.sh") + " # paketbote-update");
        }
        function fertig(code, text) {
            laeuft = false;
            if (code === 0) { neu = ""; root.melden(S.t("Paketbote"), S.t("Update installiert – Plasma lädt das Widget beim nächsten Start neu.")); }
            else fehler = text || S.t("Update fehlgeschlagen");
        }
    }
    Timer {
        interval: 12 * 3600000; running: Plasmoid.configuration.updatesSuchen; repeat: true; triggeredOnStart: true
        onTriggered: updater.pruefen()
    }

    Plasmoid.icon: "package-x-generic"
    Plasmoid.status: gruppen.aktiv.length ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus
    toolTipMainText: Logik.kopfTitel(gruppen.aktiv)
    toolTipSubText: !verbindung.bereit ? S.t("Noch nicht eingerichtet.") : verbindung.fehler ? verbindung.fehler
                    : gruppen.aktiv.slice(0, 5).map(function (s) { return Logik.titel(s) + " – " + Logik.standText(s, root.jetzt); }).join("\n")

    switchWidth: Kirigami.Units.gridUnit * 12
    switchHeight: Kirigami.Units.gridUnit * 10

    compactRepresentation: MouseArea {
        id: kompakt
        readonly property bool waagerecht: Plasmoid.formFactor !== PlasmaCore.Types.Vertical
        Layout.minimumWidth: waagerecht ? height : -1
        Layout.minimumHeight: waagerecht ? -1 : width
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
        Kirigami.Icon {
            id: symbol
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            source: "package-x-generic"
            active: kompakt.containsMouse
        }
        Rectangle {
            visible: root.gruppen.aktiv.length > 0
            anchors.right: symbol.right
            anchors.bottom: symbol.bottom
            width: Math.max(height, zahl.implicitWidth + Kirigami.Units.smallSpacing)
            height: Math.max(10, Math.round(symbol.height * 0.5))
            radius: height / 2
            color: root.gruppen.heute.length ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
            PC3.Label {
                id: zahl
                anchors.centerIn: parent
                text: root.gruppen.heute.length || root.gruppen.aktiv.length
                font.pixelSize: Math.max(7, parent.height * 0.72)
                font.weight: Font.Bold
                color: Kirigami.Theme.highlightedTextColor
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 24
        Layout.preferredHeight: Kirigami.Units.gridUnit * 30
        collapseMarginsHint: true

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                PC3.ToolButton {
                    visible: stapel.depth > 1
                    icon.name: "go-previous"
                    onClicked: stapel.pop()
                }
                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 3
                    text: stapel.depth > 1 && stapel.currentItem.titel ? stapel.currentItem.titel : Logik.kopfTitel(root.gruppen.aktiv)
                    elide: Text.ElideRight
                }
                PC3.ToolButton {
                    icon.name: "list-add"
                    onClicked: stapel.push(hinzufuegenSeite)
                    PC3.ToolTip { text: S.t("Sendung hinzufügen") }
                }
                PC3.ToolButton {
                    icon.name: "view-refresh"
                    onClicked: verbindung.laden()
                    PC3.ToolTip { text: S.t("Neu laden") }
                }
            }
        }

        QQC2.StackView {
            id: stapel
            anchors.fill: parent
            initialItem: listenSeite
        }

        Component {
            id: listenSeite
            ColumnLayout {
                spacing: 0
                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.smallSpacing
                    visible: !verbindung.bereit || verbindung.fehler !== "" || updater.neu !== ""
                    type: !verbindung.bereit || updater.neu ? Kirigami.MessageType.Information : Kirigami.MessageType.Error
                    text: !verbindung.bereit ? S.t("Einfach eine Sendungsnummer eintragen – oder mit Home Assistant verbinden: dann kommen auch die Pakete aus deinen Versandmails dazu.")
                          : verbindung.fehler ? verbindung.fehler : updater.fehler || S.t("Version %1 ist da", updater.neu)
                    actions: Kirigami.Action {
                        text: !verbindung.bereit ? S.t("Home Assistant …") : verbindung.fehler ? S.t("Neu laden") : S.t("Aktualisieren")
                        enabled: !updater.laeuft
                        onTriggered: !verbindung.bereit ? Plasmoid.internalAction("configure").trigger()
                                     : verbindung.fehler ? verbindung.laden() : updater.installieren()
                    }
                }
                PC3.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    ListView {
                        id: liste
                        model: {
                            var m = [];
                            root.gruppen.heute.forEach(function (s) { m.push({ abschnitt: S.t("Heute"), s: s }); });
                            root.gruppen.unterwegs.forEach(function (s) { m.push({ abschnitt: S.t("Unterwegs"), s: s }); });
                            root.gruppen.zugestellt.forEach(function (s) { m.push({ abschnitt: S.t("Zugestellt"), s: s }); });
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
                            jetzt: root.jetzt
                            mitKonto: verbindung.mehrereKonten
                            onClicked: stapel.push(detailSeite, { sendungId: modelData.s.id })
                        }
                        PlasmaExtras.PlaceholderMessage {
                            anchors.centerIn: parent
                            width: parent.width - Kirigami.Units.gridUnit * 2
                            visible: verbindung.geladen && liste.count === 0
                            iconName: "package-x-generic"
                            text: S.t("Keine Pakete unterwegs")
                        }
                    }
                }
            }
        }

        Component {
            id: detailSeite
            PC3.ScrollView {
                id: dseite
                property string sendungId: ""
                readonly property var sendung: verbindung.sendungen.find(function (s) { return s.id === sendungId; }) || null
                readonly property string titel: sendung ? Logik.titel(sendung) : ""
                onSendungIdChanged: { var s = verbindung.sendung(sendungId); if (s && (s.quelle === "direkt" || !s.ereignisse.length)) verbindung.einmalAbfragen(s); }
                contentWidth: availableWidth
                ColumnLayout {
                    width: parent.width
                    spacing: Kirigami.Units.largeSpacing
                    DetailInhalt {
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.largeSpacing
                        visible: !!dseite.sendung
                        sendung: dseite.sendung || { ereignisse: [], dienst: "dhl" }
                        jetzt: root.jetzt
                        mitKonto: verbindung.mehrereKonten
                        anbieterFehler: verbindung.anbieterFehler
                    }
                    RowLayout {
                        Layout.margins: Kirigami.Units.largeSpacing
                        readonly property var s: dseite.sendung
                        PC3.Button {
                            visible: !!parent.s && Logik.verfolgenAdresse(parent.s) !== ""
                            icon.name: "internet-web-browser"
                            text: S.t("Beim Dienst")
                            onClicked: Qt.openUrlExternally(Logik.verfolgenAdresse(parent.s))
                        }
                        PC3.Button {
                            visible: !!parent.s && (parent.s.erledigt || !Logik.fertig(parent.s))
                            icon.name: parent.s && parent.s.erledigt ? "edit-undo" : "dialog-ok-apply"
                            text: parent.s && parent.s.erledigt ? S.t("Doch nicht angekommen") : S.t("Angekommen")
                            onClicked: verbindung.erledigt(parent.s.id, !parent.s.erledigt)
                        }
                        PC3.Button {
                            visible: !!parent.s && parent.s.manuell
                            icon.name: "edit-delete"
                            text: S.t("Entfernen")
                            onClicked: { verbindung.entfernen(parent.s.id); stapel.pop(); }
                        }
                    }
                }
            }
        }

        Component {
            id: hinzufuegenSeite
            ColumnLayout {
                readonly property string titel: S.t("Sendung hinzufügen")
                HinzufuegenFormular {
                    id: formular
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.largeSpacing
                    ha: verbindung
                    onFertig: stapel.pop()
                }
                PC3.Button {
                    Layout.alignment: Qt.AlignRight
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    icon.name: "list-add"
                    text: S.t("Hinzufügen")
                    enabled: formular.bereit
                    onClicked: formular.senden()
                }
                Item { Layout.fillHeight: true }
            }
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: S.t("Postfach jetzt lesen")
            icon.name: "mail-receive"
            enabled: verbindung.eingerichtet
            onTriggered: verbindung.jetztNachsehen()
        }
    ]
}
