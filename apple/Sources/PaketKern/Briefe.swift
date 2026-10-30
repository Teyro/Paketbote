import Foundation

/// Ein angekündigter Brief (Deutsche Post „Briefankündigung“ – Home Assistant liest die Mails)
public struct Brief: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var datum: Date
    public var absender: String
    /// Es gibt ein Bild des Umschlags (GET /api/briefankuendigung/bild/<id>)
    public var bild: Bool
    /// Wichtiger Absender (Finanzamt, Bank … – Stichwörter in der Integration)
    public var wichtig: Bool
    /// „Angekommen“ (gilt auf allen Geräten)
    public var erledigt: Bool
    public var kontoId: String
    public var kontoName: String

    public init(id: String, datum: Date = Date(), absender: String = "", bild: Bool = false, wichtig: Bool = false, erledigt: Bool = false,
                kontoId: String = "", kontoName: String = "") {
        self.id = id; self.datum = datum; self.absender = absender; self.bild = bild; self.wichtig = wichtig; self.erledigt = erledigt
        self.kontoId = kontoId; self.kontoName = kontoName
    }

    public var titel: String { absender.isEmpty ? T("Absender unbekannt") : absender }

    public func heute(jetzt: Date = Date(), kalender: Calendar = .current) -> Bool { kalender.isDate(datum, inSameDayAs: jetzt) }
}

/// Briefe für die Anzeige: Heute · Unterwegs · Angekommen
public struct BriefGruppen: Equatable, Sendable {
    public var heute: [Brief] = []
    public var unterwegs: [Brief] = []
    public var angekommen: [Brief] = []
    public var offen: [Brief] { heute + unterwegs }

    public init() {}

    /// Briefe älter als `tage` Tage zählen nicht mehr als unterwegs (ein Brief braucht 1–3 Tage)
    public init(_ briefe: [Brief], jetzt: Date = Date(), kalender: Calendar = .current, tage: Int = 5) {
        let grenze = jetzt.addingTimeInterval(-Double(tage) * 86400)
        for b in briefe.sorted(by: { $0.datum > $1.datum }) {
            if b.erledigt || b.datum < grenze { if b.datum >= jetzt.addingTimeInterval(-14 * 86400) { angekommen.append(b) } }
            else if b.heute(jetzt: jetzt, kalender: kalender) { heute.append(b) }
            else { unterwegs.append(b) }
        }
        // wichtige zuerst
        heute.sort { $0.wichtig != $1.wichtig ? $0.wichtig : $0.datum > $1.datum }
        unterwegs.sort { $0.wichtig != $1.wichtig ? $0.wichtig : $0.datum > $1.datum }
    }
}

extension Texte {
    /// „angekündigt heute“, „angekündigt gestern“, „angekündigt Mo 26.10.“, „angekommen“
    public static func brief(_ b: Brief, jetzt: Date = Date(), mitKonto: Bool = false, kalender: Calendar = .current) -> String {
        var teile = [b.erledigt ? T("angekommen") : T("angekündigt %1", tag(b.datum, jetzt: jetzt, kalender: kalender))]
        if mitKonto && !b.kontoName.isEmpty { teile.append(b.kontoName) }
        return teile.joined(separator: " · ")
    }

    /// „heute“, „gestern“, „Mo 26.10.“
    public static func tag(_ d: Date, jetzt: Date = Date(), kalender: Calendar = .current) -> String {
        if kalender.isDate(d, inSameDayAs: jetzt) { return T("heute") }
        if let g = kalender.date(byAdding: .day, value: -1, to: jetzt), kalender.isDate(d, inSameDayAs: g) { return T("gestern") }
        return wochentag(d, kalender: kalender) + " \(kalender.component(.day, from: d)).\(kalender.component(.month, from: d))."
    }

    /// „2 Briefe“
    public static func briefe(_ n: Int) -> String { n == 1 ? T("1 Brief") : T("%1 Briefe", "\(n)") }

    /// Kopf der Briefe: „3 Briefe unterwegs“
    public static func briefTitel(_ offen: [Brief]) -> String { offen.isEmpty ? T("Keine Briefe angekündigt") : T("%1 unterwegs", briefe(offen.count)) }

    /// Für Siri und die Morgen-Mitteilung: Briefe und Pakete, die heute kommen
    public static func postSatz(_ briefe: BriefGruppen, _ pakete: Gruppen) -> String {
        var satz = heuteSatz(pakete)
        let h = briefe.heute
        if h.isEmpty { return satz }
        let wichtige = h.filter(\.wichtig)
        let namen = h.prefix(4).map(\.titel)
        var b = h.count == 1 ? T("Dazu kommt ein Brief von %1.", namen[0])
            : T("Dazu kommen %1 Briefe: %2.", "\(h.count)", namen.dropLast().joined(separator: ", ") + " " + T("und") + " " + namen.last!)
        if !wichtige.isEmpty { b += " " + (wichtige.count == 1 ? T("Wichtig: %1.", wichtige[0].titel) : T("%1 davon sind wichtig.", "\(wichtige.count)")) }
        // „Heute kommt kein Paket, und es ist auch keins unterwegs.“ klingt mit Briefen seltsam – dann kürzer
        if pakete.aktiv.isEmpty { satz = "" }
        return [satz, b].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

extension HomeAssistant {
    /// Bild des Umschlags
    public func bild(_ id: String) async throws -> Data {
        try await anfrage("/api/briefankuendigung/bild/" + id)
    }
}

/// Umschlagbilder auf dem Gerät zwischenspeichern (die Post schickt sie nur einmal)
public enum Umschlaege {
    static var ordner: URL {
        let o = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Umschlaege", isDirectory: true)
        try? FileManager.default.createDirectory(at: o, withIntermediateDirectories: true)
        return o
    }

    public static func datei(_ id: String) -> URL { ordner.appendingPathComponent(id + ".bild") }

    public static func gespeichert(_ id: String) -> Data? { try? Data(contentsOf: datei(id)) }

    /// Holen (oder aus dem Zwischenspeicher); alte Bilder (> 30 Tage) räumt `aufraeumen` weg
    public static func laden(_ id: String, ha: HomeAssistant) async -> Data? {
        if let d = gespeichert(id) { return d }
        guard let d = try? await ha.bild(id), !d.isEmpty else { return nil }
        try? d.write(to: datei(id), options: .atomic)
        return d
    }

    public static func aufraeumen(behalten ids: Set<String>) {
        guard let dateien = try? FileManager.default.contentsOfDirectory(at: ordner, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        for d in dateien where !ids.contains(d.deletingPathExtension().lastPathComponent) {
            let alt = (try? d.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if Date().timeIntervalSince(alt) > 30 * 86400 { try? FileManager.default.removeItem(at: d) }
        }
    }
}
