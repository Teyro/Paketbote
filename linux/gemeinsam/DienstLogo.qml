/*
 * Logo des Paketdienstes: Name auf seiner Farbe, abgerundet (wie in den Apple-Apps)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami
import "logik.js" as Logik

Rectangle {
    id: logo
    property string dienst: "dhl"
    property real groesse: Kirigami.Units.gridUnit * 2.4
    readonly property var d: Logik.dienst(dienst)

    width: groesse
    height: groesse
    radius: groesse * 0.26
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.lighter(logo.d.farbe, 1.12) }
        GradientStop { position: 1; color: logo.d.farbe }
    }
    Accessible.name: d.name

    Column {
        anchors.centerIn: parent
        spacing: 0
        // Karton: Fläche mit Deckelkante und Klebeband (gezeichnet – Symbole sehen je nach Thema anders aus)
        Canvas {
            id: karton
            anchors.horizontalCenter: parent.horizontalCenter
            width: logo.groesse * 0.38
            height: width * 0.86
            property color farbe: logo.d.schrift
            property color grund: logo.d.farbe
            onFarbeChanged: requestPaint()
            onPaint: {
                var c = getContext("2d"), w = width, h = height, r = w * 0.12;
                c.reset();
                c.fillStyle = farbe;
                c.beginPath();
                c.moveTo(r, 0); c.lineTo(w - r, 0); c.quadraticCurveTo(w, 0, w, r); c.lineTo(w, h - r); c.quadraticCurveTo(w, h, w - r, h);
                c.lineTo(r, h); c.quadraticCurveTo(0, h, 0, h - r); c.lineTo(0, r); c.quadraticCurveTo(0, 0, r, 0);
                c.fill();
                c.fillStyle = grund;
                c.fillRect(0, h * 0.3, w, h * 0.07);
                c.fillRect(w * 0.42, 0, w * 0.16, h * 0.42);
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: logo.d.name
            color: logo.d.schrift
            font.pixelSize: logo.groesse * (logo.d.name.length > 4 ? 0.2 : 0.24)
            font.weight: Font.Black
            font.italic: logo.dienst === "dhl"
        }
    }
}
