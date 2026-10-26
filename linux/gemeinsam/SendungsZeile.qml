/*
 * Eine Zeile der Liste: Logo, Name, Stand, Fortschritt
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "logik.js" as Logik
import "sprache.js" as S

QQC2.ItemDelegate {
    id: zeile
    property var sendung
    property bool mitKonto: false
    property double jetzt: Date.now()
    readonly property string art: Logik.standArt(sendung, jetzt)

    width: ListView.view ? ListView.view.width : implicitWidth
    Accessible.name: Logik.titel(sendung) + ", " + Logik.zeile(sendung, jetzt, mitKonto)

    contentItem: RowLayout {
        spacing: Kirigami.Units.largeSpacing
        DienstLogo {
            dienst: zeile.sendung.dienst
            groesse: Kirigami.Units.gridUnit * 2.4
            opacity: Logik.fertig(zeile.sendung) ? 0.6 : 1
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Rectangle {
                    visible: !!zeile.sendung.ruecksendung
                    implicitWidth: rueck.implicitWidth + Kirigami.Units.smallSpacing * 2
                    implicitHeight: rueck.implicitHeight
                    radius: height / 2
                    color: Qt.rgba(0.6, 0.35, 0.85, 0.18)
                    QQC2.Label { id: rueck; anchors.centerIn: parent; text: S.t("Rücksendung"); font: Kirigami.Theme.smallFont; color: "#8e44ad" }
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    text: Logik.titel(zeile.sendung)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }
            QQC2.Label {
                Layout.fillWidth: true
                text: Logik.zeile(zeile.sendung, zeile.jetzt, zeile.mitKonto)
                color: zeile.highlighted ? Kirigami.Theme.highlightedTextColor
                     : zeile.art === "problem" ? Kirigami.Theme.negativeTextColor
                     : zeile.art === "abholbereit" ? Kirigami.Theme.neutralTextColor
                     : zeile.art === "heute" ? Kirigami.Theme.linkColor : Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
                elide: Text.ElideRight
            }
            Fortschritt {
                visible: !Logik.fertig(zeile.sendung)
                Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                sendung: zeile.sendung
            }
        }
    }
}
