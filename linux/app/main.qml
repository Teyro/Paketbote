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

    title: S.t("Paketbote")
    width: Kirigami.Units.gridUnit * 50
    height: Kirigami.Units.gridUnit * 36
    minimumWidth: Kirigami.Units.gridUnit * 20
    pageStack.defaultColumnWidth: Kirigami.Units.gridUnit * 22
    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.ToolBar

    // gemeinsam mit dem Plasma-Widget: ~/.config/paketbote.conf
    Settings {
        id: einstellungen
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/paketbote.conf"
        property string adresse: ""
        property string token: ""
        property string konto: ""
        property int tageZugestellt: 14
    }

    property double jetzt: Date.now()
    Timer { interval: 60000; running: true; repeat: true; onTriggered: fenster.jetzt = Date.now() }

    Verbindung {
        id: verbindung
        adresse: einstellungen.adresse
        token: einstellungen.token
        konto: einstellungen.konto
        onMeldung: (text) => fenster.showPassiveNotification(text)
        onNeuerStand: (titel, text, id) => fenster.showPassiveNotification(titel + ": " + text, "long")
    }

    readonly property var gruppen: Logik.gruppen(verbindung.sendungen, jetzt, einstellungen.tageZugestellt)
    property string auswahl: ""
    readonly property var gewaehlt: verbindung.sendungen.find(function (s) { return s.id === fenster.auswahl; }) || null

    function zeigen(id) {
        auswahl = id;
        while (pageStack.depth > 1) pageStack.pop();
        pageStack.push(detailSeite);
    }

    pageStack.initialPage: ListenSeite {
        ha: verbindung
        gruppen: fenster.gruppen
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
        id: einstellungsSeite
        EinstellungenSeite { ha: verbindung; einstellungen: einstellungen }
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
        if (!verbindung.eingerichtet) Qt.callLater(function () { fenster.pageStack.pushDialogLayer(einstellungsSeite); });
    }
}
