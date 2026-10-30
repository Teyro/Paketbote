/*
 * Paketbote für Linux: Sendungen von DHL, Hermes, DPD, GLS, UPS und Amazon über Home Assistant.
 * Start: qml6 -a widget main.qml   (die Einstellungen teilt sie mit dem Plasma-Widget)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Controls as QQC2
import QtCore
import org.kde.kirigami as Kirigami
import "../gemeinsam"
import "../gemeinsam/logik.js" as Logik
import "../gemeinsam/sprache.js" as S

Kirigami.ApplicationWindow {
    id: fenster

    title: S.t("Post & Pakete")
    width: Kirigami.Units.gridUnit * 50
    height: Kirigami.Units.gridUnit * 36
    minimumWidth: Kirigami.Units.gridUnit * 20
    pageStack.defaultColumnWidth: Kirigami.Units.gridUnit * 22
    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.ToolBar

    // gemeinsam mit dem Plasma-Widget: ~/.config/paketbote.conf
    Settings {
        id: speicher
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/paketbote.conf"
        property string adresse: ""
        property string token: ""
        property string konto: ""
        property int tageZugestellt: 14
        // direkt verfolgte Sendungen (JSON) und Schlüssel der Anbieter
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
        /// Neue Versionen selbst installieren
        property bool autoUpdate: true
        /// Liste: "alle" | "briefe" | "pakete"
        property string bereich: "alle"
    }

    property double jetzt: Date.now()
    Timer { interval: 60000; running: true; repeat: true; onTriggered: fenster.jetzt = Date.now() }

    Verbindung {
        id: verbindung
        adresse: speicher.adresse
        token: speicher.token
        konto: speicher.konto
        auchInHA: speicher.auchInHA
        schluessel: ({ dhl: speicher.dhl, upsId: speicher.upsId, upsGeheim: speicher.upsGeheim,
                       siebzehn: speicher.siebzehn, ship24: speicher.ship24, oeffentlich: speicher.oeffentlich,
                       aus: (function () { try { return JSON.parse(speicher.aus); } catch (e) { return []; } })() })
        direkt: { try { return JSON.parse(speicher.direkt); } catch (e) { return []; } }
        onDirektGeaendert: (liste) => speicher.direkt = JSON.stringify(liste)
        onMeldung: (text) => fenster.showPassiveNotification(text)
        onNeuerStand: (titel, text, id) => {
            fenster.showPassiveNotification(titel + ": " + text, "long");
            if (mitteilung.item) mitteilung.item.zeigen(titel, text);
        }
    }

    Aktualisierung {
        id: aktualisierer
        automatisch: speicher.autoUpdate
        onMeldung: (text) => fenster.showPassiveNotification(text, "long")
    }

    // Mitteilung auf dem Schreibtisch (KDE-Benachrichtigungen; fehlt das Modul, bleibt es bei der Meldung im Fenster)
    Loader { id: mitteilung; source: "../gemeinsam/Mitteilung.qml" }

    readonly property var gruppen: Logik.gruppen(verbindung.sendungen, jetzt, speicher.tageZugestellt)
    readonly property var briefGruppen: Logik.briefGruppen(verbindung.briefe, jetzt)
    property string auswahl: ""
    readonly property var gewaehlt: verbindung.sendungen.find(function (s) { return s.id === fenster.auswahl; }) || null
    readonly property var gewaehlterBrief: verbindung.brief(fenster.auswahl)

    function zeigen(id) {
        auswahl = id;
        while (pageStack.depth > 1) pageStack.pop();
        pageStack.push(verbindung.brief(id) ? briefSeite : detailSeite);
    }

    pageStack.initialPage: ListenSeite {
        ha: verbindung
        gruppen: fenster.gruppen
        briefGruppen: fenster.briefGruppen
        bereich: speicher.bereich
        onBereichGewaehlt: (b) => speicher.bereich = b
        jetzt: fenster.jetzt
        auswahl: fenster.auswahl
        onGewaehlt: (id) => fenster.zeigen(id)
        onHinzufuegen: hinzufuegenDialog.open()
        onEinstellungen: fenster.pageStack.pushDialogLayer(einstellungsSeite)
    }

    Component {
        id: detailSeite
        DetailSeite {
            ha: verbindung
            sendung: fenster.gewaehlt
            jetzt: fenster.jetzt
        }
    }

    Component {
        id: briefSeite
        BriefSeite {
            ha: verbindung
            brief: fenster.gewaehlterBrief
            jetzt: fenster.jetzt
        }
    }

    Component {
        id: einstellungsSeite
        EinstellungenSeite { ha: verbindung; einstellungen: speicher; aktualisierung: aktualisierer }
    }

    Kirigami.Dialog {
        id: hinzufuegenDialog
        title: S.t("Sendung hinzufügen")
        padding: Kirigami.Units.largeSpacing
        preferredWidth: Kirigami.Units.gridUnit * 28
        standardButtons: Kirigami.Dialog.Cancel
        customFooterActions: [
            Kirigami.Action {
                text: S.t("Hinzufügen")
                icon.name: "list-add"
                enabled: formular.bereit
                onTriggered: formular.senden()
            }
        ]
        onOpened: formular.zuruecksetzen()
        HinzufuegenFormular {
            id: formular
            ha: verbindung
            onFertig: { hinzufuegenDialog.close(); fenster.showPassiveNotification(S.t("Hinzugefügt")); }
        }
    }

    Component.onCompleted: {
        verbindung.laden();
        // aus KRunner: --neu <Sendungsnummer>
        var a = Qt.application.arguments, i = a.indexOf("--neu");
        if (i >= 0 && a[i + 1]) { formular.vorgabe = a[i + 1]; Qt.callLater(hinzufuegenDialog.open); }
        else if (!verbindung.bereit) Qt.callLater(function () { fenster.pageStack.pushDialogLayer(einstellungsSeite); });
    }
}
