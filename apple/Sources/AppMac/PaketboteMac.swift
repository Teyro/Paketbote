import SwiftUI
import UserNotifications
import PaketKern

/// Paketbote für den Mac: Fenster mit Liste und Sendung, dazu ein Symbol in der Menüleiste
@main
struct PaketboteMac: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var kern = Kern.shared
    @State private var aktualisierer = Aktualisierer.shared

    var body: some Scene {
        Window(T("Post & Pakete"), id: "haupt") {
            Group {
                if kern.vorschau { Vorschau(kern: kern) } else { Hauptansicht(kern: kern) }
            }
            .frame(minWidth: 720, minHeight: 480)
            .onOpenURL { url in
                if url.host == "sendung" { kern.auswahl = url.lastPathComponent }
            }
        }
        .defaultSize(width: 980, height: 660)
        .commands {
            CommandGroup(after: .appInfo) {
                Button(aktualisierer.neueVersion.map { T("Update auf %1 installieren …", $0) } ?? T("Nach Updates suchen …")) {
                    Task {
                        if aktualisierer.neueVersion == nil { await aktualisierer.pruefen() }
                        if aktualisierer.neueVersion != nil { await aktualisierer.installieren() }
                    }
                }
            }
            CommandGroup(replacing: .newItem) {
                Button(T("Sendung hinzufügen …")) { kern.hinzufuegenOffen = true }.keyboardShortcut("n")
            }
            CommandGroup(replacing: .printItem) {
                Button(T("Drucken …")) { Drucken.liste(kern) }.keyboardShortcut("p")
            }
            CommandGroup(after: .sidebar) {
                Button(T("Statistik")) { kern.statistikOffen = true }.keyboardShortcut("s", modifiers: [.command, .option])
            }
        }

        MenuBarExtra {
            MenueListe(kern: kern)
        } label: {
            let n = kern.gruppen.heute.count + kern.briefGruppen.heute.count
            Label(n == 0 ? "" : "\(n)", systemImage: n == 0 ? "tray" : "tray.full.fill")
                .labelStyle(.titleAndIcon)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Kleine Liste in der Menüleiste
struct MenueListe: View {
    let kern: Kern
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let g = kern.gruppen, b = kern.briefGruppen
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(WidgetDaten(uebersicht: kern.daten.map { var u = $0; u.sendungen = kern.alle; return u } ?? Uebersicht(sendungen: kern.alle),
                                 eingerichtet: true).titel).font(.headline)
                Spacer()
                Button { Task { await kern.laden() } } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.borderless)
            }
            if !kern.fehler.isEmpty { Text(kern.fehler).font(.caption).foregroundStyle(.red) }
            Text(T("Nummer hierher ziehen oder ⌥⌘P drücken")).font(.caption2).foregroundStyle(.tertiary)
            ForEach(b.offen.prefix(4)) { br in
                Button { zeigen(br.id) } label: { BriefZeile(kern: kern, brief: br, mitKonto: kern.mehrereKonten).contentShape(Rectangle()) }
                    .buttonStyle(.plain)
            }
            ForEach(g.aktiv.prefix(8)) { s in
                Button { zeigen(s.id) } label: { SendungsZeile(sendung: s, mitKonto: kern.mehrereKonten).contentShape(Rectangle()) }
                    .buttonStyle(.plain)
            }
            if g.aktiv.isEmpty && b.offen.isEmpty { Text(T("Keine Post unterwegs")).foregroundStyle(.secondary) }
            Divider()
            HStack {
                Button(T("Alle anzeigen …")) { zeigen(nil) }
                Spacer()
                Button(T("Hinzufügen …")) { kern.hinzufuegenOffen = true; zeigen(nil) }
                Button(T("Beenden")) { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 340)
        // Sendungsnummer oder Mail-Text hier ablegen
        .dropDestination(for: String.self) { texte, _ in
            guard let n = texte.lazy.compactMap({ Dienst.nummerIn($0) }).first else { return false }
            kern.hinzufuegenNummer = n
            kern.hinzufuegenOffen = true
            zeigen(nil)
            return true
        }
    }

    private func zeigen(_ id: String?) {
        if let id { kern.auswahl = id }
        openWindow(id: "haupt")
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        MainActor.assumeIsolated {
            let kern = Kern.shared
            guard !kern.vorschau else { return }
            Tastenkuerzel.anmelden()
            // regelmäßig neu laden (die Menüleiste läuft ja immer)
            Task {
                while true {
                    await kern.laden(still: true)
                    try? await Task.sleep(for: .seconds(600))
                }
            }
            // Updates: kurz nach dem Start und dann alle 6 Stunden; automatisch installieren, wenn eingeschaltet
            Task {
                try? await Task.sleep(for: .seconds(20))
                while true {
                    let a = Aktualisierer.shared
                    await a.pruefen()
                    if a.neueVersion != nil && kern.einstellungen.autoUpdate { await a.installieren() }
                    try? await Task.sleep(for: .seconds(6 * 3600))
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let id = response.notification.request.content.userInfo["sendung"] as? String {
            await MainActor.run { Kern.shared.auswahl = id }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
