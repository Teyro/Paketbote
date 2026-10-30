/*
 * Ein Brief im Detail: Umschlag groß, Absender, angekündigt wann
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "logik.js" as Logik
import "sprache.js" as S

ColumnLayout {
    id: inhalt
    property var brief
    property string bild: ""
    property bool mitKonto: false
    property double jetzt: Date.now()
    spacing: Kirigami.Units.largeSpacing

    BriefUmschlag {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(width * 0.62, Kirigami.Units.gridUnit * 18)
        brief: inhalt.brief
        bild: inhalt.bild
        gross: true
    }
    QQC2.Label {
        visible: inhalt.brief.wichtig
        text: "⚠️ " + S.t("Wichtig")
        color: Kirigami.Theme.negativeTextColor
        font.weight: Font.DemiBold
    }
    Kirigami.Heading {
        Layout.fillWidth: true
        level: 2
        text: Logik.briefTitel(inhalt.brief)
        wrapMode: Text.Wrap
    }
    QQC2.Label {
        Layout.fillWidth: true
        text: Logik.briefZeile(inhalt.brief, inhalt.jetzt, inhalt.mitKonto)
        font.weight: Font.DemiBold
        color: inhalt.brief.erledigt ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.linkColor
    }
    QQC2.Label {
        Layout.fillWidth: true
        text: S.t("Angekündigt am %1", Qt.formatDateTime(new Date(inhalt.brief.datum), "dddd, d. MMMM yyyy, HH:mm"))
        color: Kirigami.Theme.disabledTextColor
        wrapMode: Text.Wrap
    }
}
