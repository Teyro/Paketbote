import Foundation

/// Sendungen, die die App selbst verfolgt (ohne Home Assistant) – liegen auf dem Gerät.
/// Dazu Notizen und Fotos je Sendung (auch für Sendungen aus Home Assistant).
public struct DirektListe: Codable, Equatable, Sendable {
    public var sendungen: [Sendung] = []
    /// Notiz je Sendungs-ID
    public var notizen: [String: String] = [:]

    public init() {}

    public static var ordner: URL {
        let o = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Paketbote", isDirectory: true)
        try? FileManager.default.createDirectory(at: o, withIntermediateDirectories: true)
        return o
    }
    public static var datei: URL { ordner.appendingPathComponent("direkt.json") }

    public static func laden(aus datei: URL = DirektListe.datei) -> DirektListe {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        return (try? Data(contentsOf: datei)).flatMap { try? dec.decode(DirektListe.self, from: $0) } ?? DirektListe()
    }

    public func speichern(nach datei: URL = DirektListe.datei) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        try? enc.encode(self).write(to: datei, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// Feste ID aus Dienst und Nummer (20 Hex-Zeichen, wie in der Integration)
    public static func id(_ dienst: String, _ nummer: String) -> String {
        // FNV-1a, zweimal – reicht als feste, kurze ID
        var a: UInt64 = 0xcbf29ce484222325, b: UInt64 = 0x84222325cbf29ce4
        for c in "\(dienst):\(nummer.uppercased())".utf8 {
            a = (a ^ UInt64(c)) &* 0x100000001b3
            b = (b ^ UInt64(c)) &* 0x100000001b3 &+ 7
        }
        return String((String(a, radix: 16).leftPad(16) + String(b, radix: 16).leftPad(16)).prefix(20))
    }

    @discardableResult
    public mutating func hinzufuegen(nummer: String, dienst: String, name: String, ruecksendung: Bool = false, jetzt: Date = Date()) -> Sendung {
        let n = nummer.replacingOccurrences(of: " ", with: "").uppercased()
        if let i = sendungen.firstIndex(where: { $0.nummer == n }) {
            if !name.isEmpty { sendungen[i].name = name }
            sendungen[i].ruecksendung = sendungen[i].ruecksendung || ruecksendung
            return sendungen[i]
        }
        let s = Sendung(id: Self.id(dienst, n), datum: jetzt, nummer: n, dienst: dienst, dienstName: Dienst.name(dienst), stand: "unterwegs",
                        verfolgen: Dienst.verfolgen(dienst, n)?.absoluteString ?? "", manuell: true, quelle: "direkt", ruecksendung: ruecksendung)
        var neu = s
        neu.name = name
        sendungen.insert(neu, at: 0)
        return neu
    }

    public mutating func entfernen(_ id: String) {
        sendungen.removeAll { $0.id == id }
        notizen[id] = nil
        try? FileManager.default.removeItem(at: DirektListe.foto(id))
    }

    /// Offene Sendungen bei den Anbietern abfragen; gibt die geänderten (alt, neu) zurück
    public mutating func aktualisieren(_ v: Verfolgung, jetzt: Date = Date()) async -> [(alt: Sendung, neu: Sendung)] {
        var aenderungen: [(alt: Sendung, neu: Sendung)] = []
        for i in sendungen.indices where !sendungen[i].fertig || jetzt.timeIntervalSince(sendungen[i].datum) < 3600 {
            let s = sendungen[i]
            guard let spur = await v.abfragen(s.nummer, dienst: s.dienst).spur else { continue }
            var neu = s
            if neu.uebernehmen(spur, jetzt: jetzt) {
                sendungen[i] = neu
                aenderungen.append((alt: s, neu: neu))
            }
        }
        // Zugestellte nach 30 Tagen aufräumen
        sendungen.removeAll { $0.fertig && jetzt.timeIntervalSince($0.datum) > 30 * 86400 }
        return aenderungen
    }

    /// Foto zur Sendung (JPEG auf dem Gerät)
    public static func foto(_ id: String) -> URL { ordner.appendingPathComponent("foto-\(id).jpg") }
}

extension String {
    func leftPad(_ n: Int) -> String { count >= n ? self : String(repeating: "0", count: n - count) + self }
}

/// Sendungen aus Home Assistant und direkt verfolgte zusammenführen (gleiche Nummer: Home Assistant gewinnt,
/// der Verlauf der direkten Abfrage ergänzt ihn)
public func zusammenfuehren(ha: [Sendung], direkt: [Sendung]) -> [Sendung] {
    var erg = ha
    for d in direkt {
        if let i = erg.firstIndex(where: { !d.nummer.isEmpty && $0.nummer.uppercased() == d.nummer }) {
            // Die eigene Abfrage weiß mehr (Verlauf, weiterer Stand): deren Stand übernehmen
            if !d.ereignisse.isEmpty && (erg[i].ereignisse.isEmpty || d.stufe > erg[i].stufe) {
                erg[i].stand = d.stand
                erg[i].problem = d.problem
                if !d.statusText.isEmpty { erg[i].statusText = d.statusText }
                if !d.zeitfenster.isEmpty { erg[i].zeitfenster = d.zeitfenster }
                erg[i].ereignisse = d.ereignisse
                erg[i].anbieter = d.anbieter
                erg[i].datum = max(erg[i].datum, d.datum)
            }
            if erg[i].ereignisse.isEmpty { erg[i].ereignisse = d.ereignisse }
            if erg[i].erwartet.isEmpty || (d.stufe >= erg[i].stufe && !d.erwartet.isEmpty) { erg[i].erwartet = d.erwartet.isEmpty ? erg[i].erwartet : d.erwartet }
            if erg[i].name.isEmpty { erg[i].name = d.name }
            erg[i].ruecksendung = erg[i].ruecksendung || d.ruecksendung
            if erg[i].anbieter.isEmpty { erg[i].anbieter = d.anbieter }
        } else {
            erg.append(d)
        }
    }
    return erg
}
