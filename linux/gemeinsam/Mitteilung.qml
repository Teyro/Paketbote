/*
 * Mitteilung auf dem Schreibtisch über KDE-Benachrichtigungen (über einen Loader eingebunden: fehlt das Modul, passiert nichts)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import org.kde.notification

QtObject {
    function zeigen(titel, text) {
        var n = vorlage.createObject(null, { title: titel, text: text });
        n.sendEvent();
    }
    property Component vorlage: Component {
        Notification {
            componentName: "paketbote"
            eventId: "neuerStand"
            iconName: "package-x-generic"
            autoDelete: true
        }
    }
}
