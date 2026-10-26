// Startprogramm für das Flatpak: lädt die Kirigami-Oberfläche (dieselbe wie bei der Installation mit installieren.sh)
// SPDX-License-Identifier: GPL-3.0-or-later
#include <QApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QUrl>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QApplication::setApplicationName(QStringLiteral("paketbote"));
    QApplication::setOrganizationName(QStringLiteral("Teyro"));
    QApplication::setDesktopFileName(QStringLiteral("de.teyro.Paketbote"));
    QApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("de.teyro.Paketbote")));
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE"))
        QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
    QQmlApplicationEngine engine;
    engine.load(QUrl::fromLocalFile(QStringLiteral(PAKETBOTE_QML)));
    if (engine.rootObjects().isEmpty())
        return 1;
    return app.exec();
}
