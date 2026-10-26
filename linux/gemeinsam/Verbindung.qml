/*
 * Verbindung zu Home Assistant (Integration „Briefankündigung“): Sendungen laden, hinzufügen, umbenennen,
 * als angekommen markieren, entfernen. Meldet neue Stände (Signal neuerStand).
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import "logik.js" as Logik
import "sprache.js" as S

QtObject {
    id: ha

    property string adresse: ""
    property string token: ""
    property string konto: ""
    property int minuten: 10

    property var sendungen: []
    property var konten: []
    property int version: 0
    property string fehler: ""
    property bool laedt: false
    property bool geladen: false
    /// Token abgelehnt: nicht weiter fragen (Home Assistant sperrt sonst die IP-Adresse)
    property bool abgelehnt: false

    readonly property string basis: Logik.adresse(adresse)
    readonly property bool eingerichtet: basis !== "" && token.trim() !== ""
    readonly property bool mehrereKonten: konten.length > 1

    signal neuerStand(var titel, var text, var id)
    signal meldung(string text)

    onBasisChanged: neuVerbinden()
    onTokenChanged: neuVerbinden()
    onKontoChanged: laden()

    function neuVerbinden() {
        abgelehnt = false;
        sendungen = [];
        geladen = false;
        verzoegert.restart();
    }

    function fehlerText(status) {
        if (status === 401 || status === 403) return S.t("Zugriff verweigert – bitte den Token prüfen.");
        if (status === 404) return S.t("Die Integration „Briefankündigung“ fehlt in Home Assistant (HACS, ab Version 1.4).");
        if (status === 400) return S.t("Sendungsnummer oder Paketdienst nicht erkannt.");
        if (status === 405) return S.t("Dafür die Integration in Home Assistant aktualisieren.");
        if (status === 0) return S.t("Home Assistant ist nicht erreichbar (%1).", basis);
        return S.t("Fehler %1 von Home Assistant.", status);
    }

    function anfrage(methode, pfad, koerper, fertig) {
        if (!eingerichtet) return;
        var x = new XMLHttpRequest();
        x.open(methode, basis + pfad);
        x.setRequestHeader("Authorization", "Bearer " + token.trim());
        x.setRequestHeader("Content-Type", "application/json");
        x.timeout = 20000;
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            var ok = x.status >= 200 && x.status < 300;
            var j = null;
            try { j = JSON.parse(x.responseText); } catch (e) { j = null; }
            if (x.status === 401 || x.status === 403) abgelehnt = true;
            fertig(ok ? j : null, ok ? "" : fehlerText(x.status), x.status);
        };
        x.send(koerper ? JSON.stringify(koerper) : null);
    }

    function laden() {
        if (!eingerichtet || abgelehnt) return;
        laedt = true;
        anfrage("GET", "/api/briefankuendigung/briefe", null, function (j, text) {
            laedt = false;
            if (text || !j) { fehler = text || S.t("Unerwartete Antwort von Home Assistant."); return; }
            var k = konto.trim().toLowerCase();
            var neu = Logik.sendungenAus(j).filter(function (s) { return !k || s.kontoId.toLowerCase() === k || s.kontoName.toLowerCase() === k; });
            if (geladen) {
                var alt = {};
                sendungen.forEach(function (s) { alt[s.id] = s; });
                neu.forEach(function (s) {
                    var m = Logik.mitteilung(alt[s.id], s);
                    if (m) neuerStand(m.titel, m.text, s.id);
                });
            }
            konten = j.konten || [];
            version = j.version || 1;
            sendungen = neu;
            fehler = "";
            geladen = true;
        });
    }

    /// fertig(fehlertext) – "" bei Erfolg
    function hinzufuegen(nummer, dienst, name, fertig) {
        anfrage("POST", "/api/briefankuendigung/sendung", { nummer: nummer, dienst: dienst, name: name, konto: konto }, function (j, text) {
            if (!text) laden();
            fertig(text);
        });
    }

    function umbenennen(id, name) {
        anfrage("POST", "/api/briefankuendigung/sendung/name", { id: id, name: name }, function (j, text) { if (text) meldung(text); laden(); });
    }

    function entfernen(id) {
        sendungen = sendungen.filter(function (s) { return s.id !== id || !s.manuell; });
        anfrage("POST", "/api/briefankuendigung/sendung/entfernen", { id: id }, function (j, text) { if (text) meldung(text); laden(); });
    }

    function erledigt(id, ja) {
        sendungen = sendungen.map(function (s) { return s.id === id ? Object.assign({}, s, { erledigt: ja }) : s; });
        anfrage("POST", "/api/briefankuendigung/erledigt", { id: id, erledigt: ja }, function (j, text) { if (text) meldung(text); laden(); });
    }

    function jetztNachsehen() {
        anfrage("POST", "/api/briefankuendigung/abrufen" + (konto ? "?konto=" + encodeURIComponent(konto) : ""), {}, function (j, text) {
            if (text) { meldung(text); return; }
            nachladen.zaehler = 0;
            nachladen.restart();
        });
    }

    property Timer verzoegert: Timer { interval: 500; onTriggered: ha.laden() }
    property Timer regelmaessig: Timer { interval: Math.max(1, ha.minuten) * 60000; running: ha.eingerichtet; repeat: true; onTriggered: ha.laden() }
    property Timer nachladen: Timer {
        property int zaehler: 0
        interval: 5000; repeat: true
        onTriggered: { ha.laden(); if (++zaehler >= 4) stop(); }
    }
}
