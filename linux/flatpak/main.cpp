// Startprogramm für das Flatpak: lädt die Kirigami-Oberfläche (dieselbe wie bei der Installation mit installieren.sh)
// und bietet der Oberfläche das Auto-Update an (über flatpak-spawn auf dem Rechner selbst)
// SPDX-License-Identifier: GPL-3.0-or-later
#include <QApplication>
#include <QIcon>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QRegularExpression>
#include <QUrl>

class FlatpakAktualisierer : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;

    /// Lädt PostUndPakete-<version>.flatpak von GitHub, installiert es (Benutzer- oder Systeminstallation, je nachdem
    /// wo die App liegt) und startet die App neu. false, wenn es nicht gestartet werden konnte.
    Q_INVOKABLE bool installieren(const QString &version)
    {
        static const QRegularExpression gueltig(QStringLiteral("^[0-9]+\\.[0-9]+\\.[0-9]+$"));
        if (!gueltig.match(version).hasMatch())
            return false;
        const QString url = QStringLiteral("https://github.com/Teyro/Post-und-Pakete/releases/download/v%1/PostUndPakete-%1.flatpak").arg(version);
        const QString skript = QStringLiteral(
            "set -e; T=$(mktemp -d); trap 'rm -rf \"$T\"' EXIT; "
            "if command -v curl >/dev/null 2>&1; then curl -fsSL -o \"$T/p.flatpak\" \"$1\"; else wget -q -O \"$T/p.flatpak\" \"$1\"; fi; "
            "if flatpak info --user de.teyro.Paketbote >/dev/null 2>&1; then O=--user; else O=--system; fi; "
            "flatpak install -y --noninteractive $O --bundle \"$T/p.flatpak\"; "
            "flatpak kill de.teyro.Paketbote 2>/dev/null || true; sleep 1; "
            "nohup flatpak run de.teyro.Paketbote >/dev/null 2>&1 &");
        return QProcess::startDetached(QStringLiteral("flatpak-spawn"),
                                       {QStringLiteral("--host"), QStringLiteral("sh"), QStringLiteral("-c"), skript, QStringLiteral("sh"), url});
    }
};

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
    FlatpakAktualisierer aktualisierer;
    engine.rootContext()->setContextProperty(QStringLiteral("flatpakAktualisierer"), &aktualisierer);
    engine.load(QUrl::fromLocalFile(QStringLiteral(PAKETBOTE_QML)));
    if (engine.rootObjects().isEmpty())
        return 1;
    return app.exec();
}

#include "main.moc"
