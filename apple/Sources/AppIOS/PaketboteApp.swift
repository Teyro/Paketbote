import SwiftUI
import BackgroundTasks
import UserNotifications
import PaketKern

/// Paketbote fürs iPhone und iPad
@main
struct PaketboteApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var kern = Kern.shared
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            Group {
                if kern.vorschau { Vorschau(kern: kern) } else { Hauptansicht(kern: kern) }
            }
            .onOpenURL { url in oeffnen(url) }
            .task { await UpdateHinweis.shared.pruefen() }
            .safeAreaInset(edge: .top) { UpdateBand() }
        }
        .onChange(of: phase) { _, neu in
            if neu == .active { Task { await kern.laden(still: true); await LiveAktivitaeten.abgleichen(kern, darfStarten: true) } }
            if neu == .background { Hintergrund.planen() }
        }
        .backgroundTask(.appRefresh(Hintergrund.kennung)) {
            await Hintergrund.ausfuehren()
        }
    }

    /// paketbote://sendung/<id> (aus Widgets und Mitteilungen), paketbote://neu?nummer=…
    private func oeffnen(_ url: URL) {
        guard url.scheme == "paketbote" else { return }
        switch url.host {
        case "sendung": kern.auswahl = url.lastPathComponent
        case "neu":
            // aus dem Teilen-Menü: paketbote://neu?nummer=…
            kern.hinzufuegenNummer = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "nummer" }?.value ?? ""
            kern.hinzufuegenOffen = true
        default: break
        }
    }
}

/// Hintergrundabruf: iOS weckt die App ab und zu (frühestens alle 30 Minuten) – dann neue Stände melden
enum Hintergrund {
    static let kennung = "de.teyro.paketbote.aktualisieren"

    static func planen() {
        let a = BGAppRefreshTaskRequest(identifier: kennung)
        a.earliestBeginDate = Date().addingTimeInterval(30 * 60)
        try? BGTaskScheduler.shared.submit(a)
    }

    @MainActor
    static func ausfuehren() async {
        planen()
        await Kern.shared.laden(still: true)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        MainActor.assumeIsolated {
            Uhr.shared.starten()
            Kern.shared.nachLaden = { kern in
                Uhr.shared.senden(kern)
                Task { await LiveAktivitaeten.abgleichen(kern, darfStarten: UIApplication.shared.applicationState == .active) }
            }
        }
        return true
    }

    /// Mitteilung antippen: die Sendung zeigen
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let id = response.notification.request.content.userInfo["sendung"] as? String {
            await MainActor.run { Kern.shared.auswahl = id }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

/// Neue Version auf GitHub? (Installation über Signulous bzw. die eigene Signatur)
@MainActor
@Observable
final class UpdateHinweis {
    static let shared = UpdateHinweis()
    private(set) var neu: String?
    let seite = URL(string: "https://github.com/Teyro/Paketbote/releases/latest")!
    var ausgeblendet = false

    func pruefen() async {
        guard !Kern.shared.vorschau, let url = URL(string: "https://api.github.com/repos/Teyro/Paketbote/releases/latest") else { return }
        var r = URLRequest(url: url)
        r.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (d, _) = try? await URLSession.shared.data(for: r), let j = JSON.lesen(d), let tag = j["tag_name"]?.text else { return }
        let v = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let aktuell = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        if v.compare(aktuell, options: .numeric) == .orderedDescending { neu = v }
    }
}

struct UpdateBand: View {
    @State private var u = UpdateHinweis.shared
    var body: some View {
        if let v = u.neu, !u.ausgeblendet {
            HStack {
                Label(T("Version %1 ist da", v), systemImage: "arrow.down.circle.fill").font(.callout.weight(.medium))
                Spacer()
                Link(T("Ansehen"), destination: u.seite).font(.callout.weight(.semibold))
                Button { u.ausgeblendet = true } label: { Image(systemName: "xmark") }.buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.regularMaterial)
        }
    }
}
