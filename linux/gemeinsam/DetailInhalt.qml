/*
 * Eine Sendung im Detail: Kopf mit Logo und Stand, Fortschritt, Verlauf, Angaben
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "logik.js" as Logik
import "sprache.js" as S

ColumnLayout {
    id: detail
    property var sendung
    property bool mitKonto: false
    property double jetzt: Date.now()
    readonly property string art: Logik.standArt(sendung, jetzt)
    spacing: Kirigami.Units.largeSpacing

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing
        DienstLogo {
            Layout.alignment: Qt.AlignTop
            dienst: detail.sendung.dienst
            groesse: Kirigami.Units.gridUnit * 3.6
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Heading {
                Layout.fillWidth: true
                level: 2
                text: Logik.titel(detail.sendung)
                wrapMode: Text.Wrap
            }
            QQC2.Label {
                Layout.fillWidth: true
                visible: !!detail.sendung.name && !!detail.sendung.absender && detail.sendung.name !== detail.sendung.absender
                text: detail.sendung.absender
                color: Kirigami.Theme.disabledTextColor
            }
            QQC2.Label {
                Layout.fillWidth: true
                text: Logik.standText(detail.sendung, detail.jetzt)
                font.weight: Font.DemiBold
                color: detail.art === "problem" ? Kirigami.Theme.negativeTextColor
                     : detail.art === "abholbereit" ? Kirigami.Theme.neutralTextColor
                     : detail.art === "heute" ? Kirigami.Theme.linkColor : Kirigami.Theme.textColor
            }
            QQC2.Label {
                Layout.fillWidth: true
                visible: !!detail.sendung.statusText
                text: detail.sendung.statusText
                wrapMode: Text.Wrap
                color: Kirigami.Theme.disabledTextColor
            }
            Fortschritt {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                sendung: detail.sendung
                hoehe: 6
            }
            RowLayout {
                Layout.fillWidth: true
                Repeater {
                    model: [S.t("angekündigt"), S.t("unterwegs"), S.t("in Zustellung"), S.t("zugestellt")]
                    QQC2.Label {
                        Layout.fillWidth: true
                        horizontalAlignment: index === 0 ? Text.AlignLeft : index === 3 ? Text.AlignRight : Text.AlignHCenter
                        text: modelData
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
            }
        }
    }

    Kirigami.Heading {
        level: 3
        text: S.t("Verlauf")
    }
    QQC2.Label {
        Layout.fillWidth: true
        visible: !detail.sendung.ereignisse.length
        text: S.t("Noch keine Stationen bekannt. Den genauen Verlauf zeigt die Seite des Dienstes – oder in Home Assistant einen 17TRACK- bzw. DHL-Schlüssel eintragen.")
        wrapMode: Text.Wrap
        color: Kirigami.Theme.disabledTextColor
    }
    Repeater {
        model: detail.sendung.ereignisse
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            Item {
                Layout.preferredWidth: Kirigami.Units.gridUnit
                Layout.fillHeight: true
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Kirigami.Units.smallSpacing
                    width: Kirigami.Units.gridUnit * 0.6
                    height: width
                    radius: width / 2
                    color: index === 0 ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                }
                Rectangle {
                    visible: index < detail.sendung.ereignisse.length - 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Kirigami.Units.smallSpacing + Kirigami.Units.gridUnit * 0.6
                    width: 2
                    height: parent.height
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: Kirigami.Units.largeSpacing
                spacing: 0
                QQC2.Label {
                    Layout.fillWidth: true
                    text: modelData.text
                    wrapMode: Text.Wrap
                    font.weight: index === 0 ? Font.DemiBold : Font.Normal
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    text: [Logik.ereigniszeit(modelData.zeit, detail.jetzt), modelData.ort].filter(function (x) { return x; }).join(" · ")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }
            }
        }
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true
        Kirigami.Separator { Kirigami.FormData.isSection: true }
        QQC2.Label { Kirigami.FormData.label: S.t("Dienst"); text: detail.sendung.dienstName }
        QQC2.Label {
            Kirigami.FormData.label: S.t("Sendungsnummer")
            visible: !!detail.sendung.nummer
            text: detail.sendung.nummer
        }
        QQC2.Label {
            Kirigami.FormData.label: S.t("Kundenkonto")
            visible: !!detail.sendung.kundenkonto
            text: detail.sendung.kundenkonto
        }
        QQC2.Label {
            Kirigami.FormData.label: S.t("Postfach")
            visible: detail.mitKonto && !!detail.sendung.kontoName
            text: detail.sendung.kontoName
        }
        QQC2.Label {
            Kirigami.FormData.label: S.t("Letzte Meldung")
            text: new Date(detail.sendung.datum).toLocaleString(Qt.locale(), Locale.ShortFormat)
        }
    }
}
