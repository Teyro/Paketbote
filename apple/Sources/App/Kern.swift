import Foundation
import Observation
import SwiftUI
import UserNotifications
import WidgetKit
import PaketKern

/// Zustand der App: Zugang, Sendungen, Aktionen. Gemeinsam für iPhone und Mac.
@MainActor
@Observable
final class Kern {
    static let shared = Kern()

    /// Testlauf für die Bildschirmfotos (GitHub Actions): `--vorschau` mit PB_ADRESSE, PB_TOKEN
    let vorschau = CommandLine.arguments.contains("--vorschau")
    let einstellungen: Einstellungen
    private(set) var daten: Uebersicht?
    private(set) var laedt = false
    private(set) var fehler = ""
    /// Kurze Meldung (z. B. „Hinzugefügt“ oder ein Fehler bei einer Aktion)
    var meldung = ""
    /// Gewählte Sendung (Liste → Detail; auch aus Widgets und Mitteilungen)
    var auswahl: String?
    var hinzufuegenOffen = false
    var einstellungenOffen = false

    var ha: HomeAssistant { HomeAssistant(adresse: einstellungen.adresse, token: einstellungen.token, konto: einstellungen.konto) }
    var gruppen: Gruppen { Gruppen(daten?.sendungen ?? [], tage: einstellungen.tageZugestellt) }
    var mehrereKonten: Bool { daten?.mehrereKonten ?? false }

    func sendung(_ id: String?) -> Sendung? { daten?.sendungen.first { $0.id == id } }

    private init() {
        Sprache.laden()
        einstellungen = Einstellungen(vorschau: vorschau)
        if vorschau {
            let env = ProcessInfo.processInfo.environment
            einstellungen.adresse = env["PB_ADRESSE"] ?? "http://127.0.0.1:8123"
            einstellungen.token = env["PB_TOKEN"] ?? "test-token"
        } else {
            daten = Ablage.lesen()
        }
    }

    /// Neu laden; meldet neue Stände (Mitteilungen) und schreibt den Stand für die Widgets
    func laden(still: Bool = false) async {
        guard einstellungen.eingerichtet else { fehler = ""; return }
        if !still { laedt = true }
        defer { laedt = false }
        do {
            let neu = try await ha.laden()
            if daten != nil && einstellungen.mitteilungen { await melden(alt: daten!, neu: neu) }
            daten = neu
            fehler = ""
            Ablage.schreiben(neu)
            WidgetCenter.shared.reloadAllTimelines()
        } catch let e as HAFehler {
            fehler = e.text
        } catch {
            fehler = error.localizedDescription
        }
    }

    /// Eine Aktion ausführen, danach neu laden; Fehler als Meldung
    private func aktion(erfolg: String = "", _ arbeit: @escaping () async throws -> Void) async -> Bool {
        do {
            try await arbeit()
            if !erfolg.isEmpty { meldung = erfolg }
            await laden(still: true)
            return true
        } catch let e as HAFehler {
            meldung = e.text
        } catch {
            meldung = error.localizedDescription
        }
        return false
    }

    func hinzufuegen(nummer: String, dienst: String, name: String) async -> Bool {
        let ha = ha
        return await aktion(erfolg: T("Hinzugefügt")) { try await ha.hinzufuegen(nummer: nummer, dienst: dienst, name: name) }
    }

    func entfernen(_ s: Sendung) async {
        if auswahl == s.id { auswahl = nil }
        let ha = ha
        _ = await aktion { try await ha.entfernen(s.id) }
    }

    func umbenennen(_ s: Sendung, _ name: String) async {
        let ha = ha
        _ = await aktion { try await ha.umbenennen(s.id, name) }
    }

    func erledigt(_ s: Sendung, _ ja: Bool) async {
        // sofort zeigen, dann speichern
        if var d = daten, let i = d.sendungen.firstIndex(where: { $0.id == s.id }) {
            d.sendungen[i].erledigt = ja
            daten = d
        }
        let ha = ha
        _ = await aktion { try await ha.erledigt(s.id, ja) }
    }

    /// Home Assistant jetzt ins Postfach schauen lassen, ein paar Mal nachladen
    func jetztNachsehen() async {
        let ha = ha
        guard await aktion({ try await ha.abrufen() }) else { return }
        for _ in 0..<4 {
            try? await Task.sleep(for: .seconds(5))
            await laden(still: true)
        }
    }

    // MARK: Mitteilungen (lokal, wenn die App bzw. ihr Hintergrundabruf etwas Neues sieht)

    func mitteilungenErlauben() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    private func melden(alt: Uebersicht, neu: Uebersicht) async {
        let vorher = Dictionary(alt.sendungen.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for s in neu.sendungen {
            guard let m = Texte.mitteilung(alt: vorher[s.id], neu: s) else { continue }
            let inhalt = UNMutableNotificationContent()
            inhalt.title = m.titel
            inhalt.body = m.text
            inhalt.threadIdentifier = "pakete"
            inhalt.userInfo = ["sendung": s.id]
            inhalt.sound = .default
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "\(s.id)-\(s.stand)", content: inhalt, trigger: nil))
        }
    }
}

/// Einstellungen: Adresse, Postfach, Mitteilungen in der gemeinsamen Ablage (auch für Widgets und Kurzbefehle);
/// der Token auf dem Mac im Schlüsselbund, auf dem iPhone in der App-Gruppe (die Widgets laden selbst).
@MainActor
@Observable
final class Einstellungen {
    @ObservationIgnored private let d = Ablage.einstellungen
    @ObservationIgnored private let vorschau: Bool

    var adresse: String { didSet { if !vorschau { d.set(adresse, forKey: "adresse") } } }
    var konto: String { didSet { if !vorschau { d.set(konto, forKey: "konto") } } }
    var mitteilungen: Bool { didSet { d.set(mitteilungen, forKey: "mitteilungen") } }
    /// Sortierung der Zugestellten: so viele Tage zeigen
    var tageZugestellt: Int { didSet { d.set(tageZugestellt, forKey: "tageZugestellt") } }
    var token: String {
        didSet {
            guard !vorschau else { return }
            #if os(macOS)
            Schluesselbund.speichern(token)
            #else
            d.set(token, forKey: "token")
            #endif
        }
    }

    init(vorschau: Bool) {
        self.vorschau = vorschau
        d.register(defaults: ["mitteilungen": true, "tageZugestellt": 14])
        adresse = vorschau ? "" : d.string(forKey: "adresse") ?? ""
        konto = vorschau ? "" : d.string(forKey: "konto") ?? ""
        mitteilungen = d.bool(forKey: "mitteilungen")
        tageZugestellt = d.integer(forKey: "tageZugestellt")
        #if os(macOS)
        token = vorschau ? "" : Schluesselbund.lesen() ?? ""
        #else
        token = vorschau ? "" : d.string(forKey: "token") ?? ""
        #endif
    }

    var eingerichtet: Bool { !adresse.isEmpty && !token.isEmpty }
}

#if os(macOS)
import Security

/// Token im Schlüsselbund von macOS
enum Schluesselbund {
    static let dienst = "de.teyro.paketbote"
    static var basis: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: dienst, kSecAttrAccount as String: "token"]
    }

    static func lesen() -> String? {
        var q = basis
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var e: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &e) == errSecSuccess, let d = e as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func speichern(_ token: String) {
        guard !token.isEmpty else { SecItemDelete(basis as CFDictionary); return }
        let daten = Data(token.utf8)
        if SecItemUpdate(basis as CFDictionary, [kSecValueData as String: daten] as CFDictionary) == errSecItemNotFound {
            var neu = basis
            neu[kSecValueData as String] = daten
            neu[kSecAttrLabel as String] = "Paketbote – Home Assistant Token"
            SecItemAdd(neu as CFDictionary, nil)
        }
    }
}
#endif
