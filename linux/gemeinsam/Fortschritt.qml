/*
 * Fortschritt in vier Schritten: angekündigt · unterwegs · in Zustellung · zugestellt
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami
import "logik.js" as Logik

Row {
    id: f
    property var sendung
    property real hoehe: 4
    readonly property int stufe: sendung ? Logik.stufe(sendung) : 0
    readonly property color farbe: sendung && sendung.problem ? Kirigami.Theme.neutralTextColor
                                   : stufe === 4 ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.highlightColor
    spacing: 3
    Repeater {
        model: 4
        Rectangle {
            width: (f.width - 9) / 4
            height: f.hoehe
            radius: height / 2
            color: index < f.stufe ? f.farbe : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
        }
    }
}
