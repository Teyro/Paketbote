import QtQuick
import org.kde.plasma.configuration
import "../ui/gemeinsam/sprache.js" as S

ConfigModel {
    ConfigCategory {
        name: S.t("Allgemein")
        icon: "package-x-generic"
        source: "configAllgemein.qml"
    }
}
