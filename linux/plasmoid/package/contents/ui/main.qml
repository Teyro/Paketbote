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

    readonly property var gruppenAlle: Logik.gruppen(verbindung.sendungen, jetzt, gemeinsam.tageZugestellt)
    readonly property var briefGruppenAlle: Logik.briefGruppen(verbindung.briefe, jetzt)
    /// Was die Kachel zeigt (Einstellungen): alles, nur Briefe oder nur Pakete
    readonly property string inhalt: Plasmoid.configuration.inhalt || "alle"
    readonly property var leerP: ({ heute: [], unterwegs: [], zugestellt: [], aktiv: [] })
    readonly property var leerB: ({ heute: [], unterwegs: [], angekommen: [], offen: [] })
    readonly property var gruppen: inhalt === "briefe" ? leerP : gruppenAlle
    readonly property var briefGruppen: inhalt === "pakete" ? leerB : briefGruppenAlle
    readonly property int heuteZahl: gruppen.heute.length + briefGruppen.heute.length
    readonly property int offenZahl: gruppen.aktiv.length + briefGruppen.offen.length

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
        shell.connectSource("notify-send -a Post & Pakete -i package-x-generic " + sh(titel) + " " + sh(text));
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
            x.open("GET", "https://api.github.com/repos/Teyro/Post-und-Pakete/releases/latest");
            x.onreadystatechange = function () {
                if (x.readyState !== XMLHttpRequest.DONE || x.status !== 200) return;
                var j = JSON.parse(x.responseText), v = String(j.tag_name || "").replace(/^v/, "");
                var a = (j.assets || []).find(function (a) { return /^post-und-pakete-linux-[\d.]+\.tar\.gz$/.test(a.name)
                    && String(a.browser_download_url).indexOf("https://github.com/Teyro/Post-und-Pakete/releases/download/") === 0; });
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
            shell.connectSource("sh -c " + sh("d=$(mktemp -d) && cd \"$d\" && curl -fsSL " + sh(datei) + " | tar xz && sh ./post-und-pakete/installieren.sh") + " # paketbote-update");
        }
        function fertig(code, text) {
            laeuft = false;
            if (code === 0) { neu = ""; root.melden(S.t("Post & Pakete"), S.t("Update installiert – Plasma lädt das Widget beim nächsten Start neu.")); }
            else fehler = text || S.t("Update fehlgeschlagen");
        }
    }
    Timer {
        interval: 12 * 3600000; running: Plasmoid.configuration.updatesSuchen; repeat: true; triggeredOnStart: true
        onTriggered: updater.pruefen()
    }

    readonly property string symbolName: inhalt === "briefe" ? "mail-message" : inhalt === "pakete" ? "package-x-generic" : "mail-folder-inbox"
    Plasmoid.icon: symbolName
    Plasmoid.status: offenZahl ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus
    toolTipMainText: Logik.postTitel(briefGruppen.offen, gruppen.aktiv)
    toolTipSubText: !verbindung.bereit ? S.t("Noch nicht eingerichtet.") : verbindung.fehler ? verbindung.fehler
                    : briefGruppen.offen.slice(0, 3).map(function (b) { return "✉ " + Logik.briefTitel(b) + " – " + Logik.briefZeile(b, root.jetzt, false); })
                      .concat(gruppen.aktiv.slice(0, 5).map(function (s) { return Logik.titel(s) + " – " + Logik.standText(s, root.jetzt); })).join("\n")

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
            source: root.symbolName
            active: kompakt.containsMouse
        }
        Rectangle {
            visible: root.offenZahl > 0
            anchors.right: symbol.right
            anchors.bottom: symbol.bottom
            width: Math.max(height, zahl.implicitWidth + Kirigami.Units.smallSpacing)
            height: Math.max(10, Math.round(symbol.height * 0.5))
            radius: height / 2
            color: root.heuteZahl ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
            PC3.Label {
                id: zahl
                anchors.centerIn: parent
                text: root.heuteZahl || root.offenZahl
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
                    text: stapel.depth > 1 && stapel.currentItem.titel ? stapel.currentItem.titel : Logik.postTitel(root.briefGruppen.offen, root.gruppen.aktiv)
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
                    text: !verbindung.bereit ? S.t("Einfach eine Sendungsnummer eintragen – oder mit Home Assistant verbinden: dann kommen die angekündigten Briefe und die Pakete aus deinen Versandmails dazu.")
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
                            var m = [], b = root.briefGruppen, g = root.gruppen;
                            b.heute.forEach(function (x) { m.push({ abschnitt: S.t("Heute"), b: x }); });
                            g.heute.forEach(function (s) { m.push({ abschnitt: S.t("Heute"), s: s }); });
                            b.unterwegs.forEach(function (x) { m.push({ abschnitt: S.t("Unterwegs"), b: x }); });
                            g.unterwegs.forEach(function (s) { m.push({ abschnitt: S.t("Unterwegs"), s: s }); });
                            b.angekommen.slice(0, 5).forEach(function (x) { m.push({ abschnitt: S.t("Angekommen"), b: x }); });
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
                                    jetzt: root.jetzt
                                    mitKonto: verbindung.mehrereKonten
                                    onClicked: stapel.push(detailSeite, { sendungId: eintrag.modelData.s.id })
                                }
                            }
                            Component {
                                id: briefKomponente
                                BriefZeile {
                                    brief: eintrag.modelData.b
                                    bild: verbindung.bilder[eintrag.modelData.b.id] || ""
                                    jetzt: root.jetzt
                                    mitKonto: verbindung.mehrereKonten
                                    onClicked: stapel.push(briefSeite, { briefId: eintrag.modelData.b.id })
                                }
                            }
                        }
                        PlasmaExtras.PlaceholderMessage {
                            anchors.centerIn: parent
                            width: parent.width - Kirigami.Units.gridUnit * 2
                            visible: verbindung.geladen && liste.count === 0
                            iconName: root.symbolName
                            text: root.inhalt === "briefe" ? S.t("Keine Briefe angekündigt") : root.inhalt === "pakete" ? S.t("Keine Pakete unterwegs") : S.t("Keine Post unterwegs")
                        }
                    }
                }
            }
        }

        Component {
            id: briefSeite
            PC3.ScrollView {
                id: bseite
                property string briefId: ""
                readonly property var brief: verbindung.brief(briefId)
                readonly property string titel: brief ? Logik.briefTitel(brief) : ""
                contentWidth: availableWidth
                ColumnLayout {
                    width: parent.width
                    spacing: Kirigami.Units.largeSpacing
                    BriefInhalt {
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.largeSpacing
                        visible: !!bseite.brief
                        brief: bseite.brief || { datum: 0, absender: "", wichtig: false, erledigt: false }
                        bild: bseite.brief ? (verbindung.bilder[bseite.brief.id] || "") : ""
                        jetzt: root.jetzt
                        mitKonto: verbindung.mehrereKonten
                    }
                    PC3.Button {
                        Layout.margins: Kirigami.Units.largeSpacing
                        visible: !!bseite.brief
                        icon.name: bseite.brief && bseite.brief.erledigt ? "edit-undo" : "dialog-ok-apply"
                        text: bseite.brief && bseite.brief.erledigt ? S.t("Doch nicht angekommen") : S.t("Angekommen")
                        onClicked: verbindung.briefErledigt(bseite.brief.id, !bseite.brief.erledigt)
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
