/*
 * Auto-Update: sucht alle 6 Stunden auf GitHub nach einer neuen Version und installiert sie
 *   – Flatpak: über das Startprogramm (flatpak-spawn), sonst über paketbote-update:<Version> (aktualisieren.sh)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import "version.js" as Version
import "sprache.js" as S

QtObject {
    id: aktualisierung
    /// automatisch installieren (sonst nur Bescheid geben)
    property bool automatisch: true
    /// neuere Version auf GitHub ("" = keine)
    property string neu: ""
    property bool laeuft: false
    readonly property string version: Version.VERSION
    readonly property string seite: "https://github.com/Teyro/Post-und-Pakete/releases/latest"
    signal meldung(string text)

    function neuer(a, b) {
        var x = String(a).split("."), y = String(b).split(".");
        for (var i = 0; i < 3; i++) {
            var d = (parseInt(x[i]) || 0) - (parseInt(y[i]) || 0);
            if (d) return d > 0;
        }
        return false;
    }

    function pruefen(sofortInstallieren) {
        var x = new XMLHttpRequest();
        x.open("GET", "https://api.github.com/repos/Teyro/Post-und-Pakete/releases/latest");
        x.setRequestHeader("Accept", "application/vnd.github+json");
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE || x.status !== 200) return;
            var j = null;
            try { j = JSON.parse(x.responseText); } catch (e) { return; }
            var v = String(j.tag_name || "").replace(/^v/, "");
            if (!/^\d+\.\d+\.\d+$/.test(v) || !neuer(v, version)) { neu = ""; return; }
            neu = v;
            if (automatisch || sofortInstallieren) installieren();
            else meldung(S.t("Version %1 ist da", v));
        };
        x.send();
    }

    function installieren() {
        if (!neu || laeuft) return;
        laeuft = true;
        var ok = false;
        if (typeof flatpakAktualisierer !== "undefined" && flatpakAktualisierer) ok = flatpakAktualisierer.installieren(neu);
        else ok = Qt.openUrlExternally("paketbote-update:" + neu);
        if (ok) {
            meldung(S.t("Update auf %1 wird installiert …", neu));
        } else {
            laeuft = false;
            meldung(S.t("Update auf %1 bitte von GitHub laden.", neu));
            Qt.openUrlExternally(seite);
        }
    }

    property Timer zeitgeber: Timer {
        interval: 6 * 3600 * 1000
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: aktualisierung.pruefen(false)
    }
    property Timer start: Timer {
        interval: 30000
        running: true
        onTriggered: aktualisierung.pruefen(false)
    }
}
