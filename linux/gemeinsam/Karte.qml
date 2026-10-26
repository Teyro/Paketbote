/*
 * Karte der Stationen einer Sendung (OpenStreetMap über QtLocation; Orte über photon.komoot.io nachgeschlagen)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtLocation
import QtPositioning

Map {
    id: karte
    property var ereignisse: []
    property var punkte: []
    // Orte merken, damit nicht jede Ansicht neu fragt
    property var gemerkt: ({})

    plugin: Plugin {
        name: "osm"
        PluginParameter { name: "osm.useragent"; value: "Paketbote/1.2 (github.com/Teyro/Paketbote)" }
        PluginParameter { name: "osm.mapping.providersrepository.disabled"; value: true }
    }
    zoomLevel: 6
    center: QtPositioning.coordinate(51.2, 10.4)
    copyrightsVisible: true

    onEreignisseChanged: nachschlagen()

    function nachschlagen() {
        var orte = [];
        ereignisse.forEach(function (e) { if (e.ort && orte.indexOf(e.ort) < 0) orte.push(e.ort); });
        orte = orte.slice(0, 8);
        var erg = new Array(orte.length), offen = orte.length;
        if (!offen) { punkte = []; return; }
        orte.forEach(function (ort, i) {
            function fertig(k) {
                erg[i] = k ? { ort: ort, k: k } : null;
                if (--offen === 0) zeigen(erg.filter(function (x) { return x; }));
            }
            if (gemerkt[ort]) return fertig(gemerkt[ort]);
            var x = new XMLHttpRequest();
            x.open("GET", "https://photon.komoot.io/api/?limit=1&lang=de&lat=50.5&lon=10.5&q=" + encodeURIComponent(ort));
            x.onreadystatechange = function () {
                if (x.readyState !== XMLHttpRequest.DONE) return;
                try {
                    var c = JSON.parse(x.responseText).features[0].geometry.coordinates;
                    var k = QtPositioning.coordinate(c[1], c[0]);
                    gemerkt[ort] = k;
                    fertig(k);
                } catch (e) { fertig(null); }
            };
            x.send();
        });
    }

    function zeigen(liste) {
        punkte = liste;
        if (!liste.length) return;
        var pfad = liste.map(function (p) { return p.k; });
        karte.fitViewportToGeoShape(QtPositioning.path(pfad), 40);
        if (liste.length === 1) karte.zoomLevel = 10;
    }

    MapPolyline {
        line.width: 3
        line.color: "#3daee9"
        path: karte.punkte.map(function (p) { return p.k; })
    }
    MapItemView {
        model: karte.punkte
        delegate: MapQuickItem {
            required property var modelData
            required property int index
            coordinate: modelData.k
            anchorPoint.x: 7
            anchorPoint.y: 7
            sourceItem: Rectangle {
                width: 14; height: 14; radius: 7
                color: index === 0 ? "#3daee9" : "#7f8c8d"
                border.color: "white"; border.width: 2
            }
        }
    }
}
