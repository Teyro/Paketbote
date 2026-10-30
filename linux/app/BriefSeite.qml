/*
 * Ein Brief: Umschlag groß, Angekommen, Teilen
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../gemeinsam"
import "../gemeinsam/logik.js" as Logik
import "../gemeinsam/sprache.js" as S

Kirigami.ScrollablePage {
    id: seite
    required property var ha
    property var brief
    property double jetzt: Date.now()

    title: brief ? Logik.briefTitel(brief) : ""

    actions: [
        Kirigami.Action {
            text: seite.brief && seite.brief.erledigt ? S.t("Doch nicht angekommen") : S.t("Angekommen")
            icon.name: seite.brief && seite.brief.erledigt ? "edit-undo" : "dialog-ok-apply"
            visible: !!seite.brief
            onTriggered: seite.ha.briefErledigt(seite.brief.id, !seite.brief.erledigt)
        }
    ]

    BriefInhalt {
        visible: !!seite.brief
        brief: seite.brief || { datum: 0, absender: "", wichtig: false, erledigt: false }
        bild: seite.brief ? (seite.ha.bilder[seite.brief.id] || "") : ""
        jetzt: seite.jetzt
        mitKonto: seite.ha.mehrereKonten
    }
}
