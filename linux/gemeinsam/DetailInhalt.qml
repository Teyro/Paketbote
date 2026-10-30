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
    property var anbieterFehler: ({})
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
            Kirigami.Chip {
                visible: !!detail.sendung.ruecksendung
                text: S.t("Rücksendung")
                checkable: false
                closable: false
            }
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

    // Abholen: Code groß, Abholstelle, Frist, Route
    Rectangle {
        Layout.fillWidth: true
        visible: Logik.zumAbholen(detail.sendung)
        implicitHeight: abholen.implicitHeight + Kirigami.Units.largeSpacing * 2
        radius: Kirigami.Units.cornerRadius
        color: Qt.rgba(Kirigami.Theme.neutralTextColor.r, Kirigami.Theme.neutralTextColor.g, Kirigami.Theme.neutralTextColor.b, 0.12)
        ColumnLayout {
            id: abholen
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Kirigami.Units.largeSpacing }
            spacing: Kirigami.Units.smallSpacing
            QQC2.Label {
                visible: !!detail.sendung.abholcode
                text: S.t("Abholcode")
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }
            RowLayout {
                visible: !!detail.sendung.abholcode
                QQC2.Label {
                    text: detail.sendung.abholcode
                    font.family: "monospace"
                    font.pixelSize: Kirigami.Units.gridUnit * 2
                    font.weight: Font.Bold
                    Accessible.name: S.t("Abholcode %1", detail.sendung.abholcode)
                }
                QQC2.ToolButton {
                    icon.name: "edit-copy"
                    text: S.t("Kopieren")
                    display: QQC2.AbstractButton.IconOnly
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: text
                    onClicked: { kopie.text = detail.sendung.abholcode; kopie.selectAll(); kopie.copy(); }
                    TextEdit { id: kopie; visible: false }
                }
            }
            QQC2.Label {
                Layout.fillWidth: true
                visible: !!detail.sendung.abholort
                text: detail.sendung.abholort
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }
            QQC2.Label {
                Layout.fillWidth: true
                visible: !!detail.sendung.abholadresse
                text: detail.sendung.abholadresse
                wrapMode: Text.Wrap
            }
            QQC2.Label {
                Layout.fillWidth: true
                readonly property double bis: Logik.tagAus(detail.sendung.abholfrist)
                visible: bis > 0
                text: S.t("Abholen bis %1", bis ? Logik.kurzTag(bis, detail.jetzt) : "")
                color: bis && bis - detail.jetzt < 2 * 86400000 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
            }
            QQC2.Button {
                visible: !!(detail.sendung.abholort || detail.sendung.abholadresse)
                icon.name: "map-flat"
                text: S.t("Route starten")
                onClicked: Qt.openUrlExternally(Logik.routeAdresse(detail.sendung))
            }
        }
    }

    // Rückgabefrist nach der Zustellung
    Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: Logik.rueckgabeOffen(detail.sendung, detail.jetzt)
        type: Kirigami.MessageType.Information
        icon.name: "edit-undo"
        text: S.t("Rückgabe bis %1", Logik.rueckgabeOffen(detail.sendung, detail.jetzt) ? Logik.kurzTag(Logik.rueckgabeBis(detail.sendung), detail.jetzt) : "")
    }

    // Karte der Stationen (OpenStreetMap; fehlt QtLocation, bleibt sie weg)
    Loader {
        Layout.fillWidth: true
        Layout.preferredHeight: active && status === Loader.Ready ? Kirigami.Units.gridUnit * 12 : 0
        active: !Logik.zumAbholen(detail.sendung) && detail.sendung.ereignisse.some(function (e) { return e.ort; })
        source: "Karte.qml"
        onLoaded: item.ereignisse = Qt.binding(function () { return detail.sendung.ereignisse; })
    }

    Kirigami.Heading {
        level: 3
        text: S.t("Verlauf")
    }
    QQC2.Label {
        Layout.fillWidth: true
        visible: !detail.sendung.ereignisse.length
        text: S.t("Noch keine Stationen bekannt. Den genauen Verlauf zeigt die Seite des Dienstes – oder unter Einstellungen → Direkt verfolgen einen Anbieter eintragen.")
        wrapMode: Text.Wrap
        color: Kirigami.Theme.disabledTextColor
    }
    Repeater {
        model: detail.sendung.ereignisse.length ? [] : Object.keys(detail.anbieterFehler)
        QQC2.Label {
            Layout.fillWidth: true
            text: modelData + ": " + detail.anbieterFehler[modelData]
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }
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
            Kirigami.FormData.label: S.t("Quelle")
            text: (detail.sendung.quelle === "direkt" ? S.t("direkt verfolgt") : S.t("Home Assistant")) + (detail.sendung.anbieter ? " · " + detail.sendung.anbieter : "")
        }
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
