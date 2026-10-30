/*
 * Ein Brief in der Liste: Umschlag, Absender, angekündigt wann
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
    property var brief
    property string bild: ""
    property bool mitKonto: false
    property double jetzt: Date.now()
    readonly property bool heute: new Date(brief.datum).toDateString() === new Date(jetzt).toDateString()

    width: ListView.view ? ListView.view.width : implicitWidth
    Accessible.name: S.t("Brief von %1", Logik.briefTitel(brief)) + ", " + Logik.briefZeile(brief, jetzt, mitKonto)

    contentItem: RowLayout {
        spacing: Kirigami.Units.largeSpacing
        BriefUmschlag {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 3.6
            Layout.preferredHeight: Kirigami.Units.gridUnit * 2.4
            brief: zeile.brief
            bild: zeile.bild
            opacity: zeile.brief.erledigt ? 0.6 : 1
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Rectangle {
                    visible: zeile.brief.wichtig && !zeile.brief.erledigt
                    implicitWidth: wichtig.implicitWidth + Kirigami.Units.smallSpacing * 2
                    implicitHeight: wichtig.implicitHeight
                    radius: height / 2
                    color: Qt.rgba(Kirigami.Theme.negativeTextColor.r, Kirigami.Theme.negativeTextColor.g, Kirigami.Theme.negativeTextColor.b, 0.16)
                    QQC2.Label { id: wichtig; anchors.centerIn: parent; text: S.t("Wichtig"); font: Kirigami.Theme.smallFont; color: Kirigami.Theme.negativeTextColor }
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    text: Logik.briefTitel(zeile.brief)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }
            QQC2.Label {
                Layout.fillWidth: true
                text: Logik.briefZeile(zeile.brief, zeile.jetzt, zeile.mitKonto)
                color: zeile.highlighted ? Kirigami.Theme.highlightedTextColor : zeile.heute && !zeile.brief.erledigt ? Kirigami.Theme.linkColor : Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
                elide: Text.ElideRight
            }
        }
    }
}
