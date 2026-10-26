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
        Window(T("Paketbote"), id: "haupt") {
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
            let g = kern.gruppen
            Label(g.heute.isEmpty ? "" : "\(g.heute.count)", systemImage: g.heute.isEmpty ? "shippingbox" : "shippingbox.fill")
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
        let g = kern.gruppen
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(Texte.titel(g.aktiv)).font(.headline)
                Spacer()
                Button { Task { await kern.laden() } } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.borderless)
            }
            if !kern.fehler.isEmpty { Text(kern.fehler).font(.caption).foregroundStyle(.red) }
            Text(T("Nummer hierher ziehen oder ⌥⌘P drücken")).font(.caption2).foregroundStyle(.tertiary)
            ForEach(g.aktiv.prefix(8)) { s in
                Button { zeigen(s.id) } label: { SendungsZeile(sendung: s, mitKonto: kern.mehrereKonten).contentShape(Rectangle()) }
                    .buttonStyle(.plain)
            }
            if g.aktiv.isEmpty { Text(T("Keine Pakete unterwegs")).foregroundStyle(.secondary) }
            Divider()
            HStack {
                Button(T("Alle Pakete …")) { zeigen(nil) }
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
            Task {
                try? await Task.sleep(for: .seconds(20))
                await Aktualisierer.shared.pruefen()
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
