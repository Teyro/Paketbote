import Foundation

/// Ein Eintrag im Archiv von Home Assistant (Datum, Absender, Art, Dienst)
public struct ArchivEintrag: Codable, Hashable, Sendable {
    public var datum: Date
    public var absender: String
    public var paket: Bool
    public var dienst: String

    public init(datum: Date, absender: String, paket: Bool, dienst: String) {
        self.datum = datum; self.absender = absender; self.paket = paket; self.dienst = dienst
    }
}

/// Auswertung: Pakete pro Monat, häufigste Shops, Dienste, wie schnell geliefert wird
public struct Statistik: Equatable, Sendable {
    public struct Monat: Equatable, Sendable, Identifiable {
        public var id: String { schluessel }
        public var schluessel: String   // "2026-10"
        public var name: String         // "Okt"
        public var anzahl: Int
        /// Briefe in diesem Monat
        public var briefe: Int = 0
    }
    public var monate: [Monat] = []
    public var shops: [(name: String, anzahl: Int)] = []
    public var dienste: [(dienst: String, anzahl: Int)] = []
    /// Durchschnittliche Tage von der ersten Meldung bis zur Zustellung je Dienst
    public var laufzeit: [(dienst: String, tage: Double)] = []
    public var gesamt = 0
    public var briefeGesamt = 0

    public static func == (a: Statistik, b: Statistik) -> Bool {
        a.monate == b.monate && a.gesamt == b.gesamt && a.shops.map(\.name) == b.shops.map(\.name)
    }

    public init(archiv: [ArchivEintrag], sendungen: [Sendung], jetzt: Date = Date(), kalender: Calendar = .current) {
        // Archiv (2 Jahre) plus Sendungen, die (noch) nicht im Archiv stehen (z. B. direkt verfolgt)
        var pakete = archiv.filter(\.paket)
        for s in sendungen where !pakete.contains(where: { abs($0.datum.timeIntervalSince(s.datum)) < 86400 * 3 && $0.absender == s.absender && !s.absender.isEmpty }) {
            pakete.append(ArchivEintrag(datum: s.ereignisse.last?.zeit ?? s.datum, absender: s.titel, paket: true, dienst: s.dienst))
        }
        gesamt = pakete.count
        let briefe = archiv.filter { !$0.paket }
        briefeGesamt = briefe.count
        let namen = [T("Jan"), T("Feb"), T("Mär"), T("Apr"), T("Mai"), T("Jun"), T("Jul"), T("Aug"), T("Sep"), T("Okt"), T("Nov"), T("Dez")]
        for i in (0..<12).reversed() {
            guard let d = kalender.date(byAdding: .month, value: -i, to: jetzt) else { continue }
            let k = kalender.dateComponents([.year, .month], from: d)
            let schluessel = String(format: "%04d-%02d", k.year ?? 0, k.month ?? 0)
            let n = pakete.filter { kalender.dateComponents([.year, .month], from: $0.datum) == k }.count
            let nb = briefe.filter { kalender.dateComponents([.year, .month], from: $0.datum) == k }.count
            monate.append(Monat(schluessel: schluessel, name: namen[(k.month ?? 1) - 1], anzahl: n, briefe: nb))
        }
        var s: [String: Int] = [:], d: [String: Int] = [:]
        for p in pakete {
            if !p.absender.isEmpty { s[p.absender, default: 0] += 1 }
            d[p.dienst.isEmpty ? "dhl" : p.dienst, default: 0] += 1
        }
        shops = s.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(8).map { ($0.key, $0.value) }
        dienste = d.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
        var dauer: [String: [Double]] = [:]
        for s in sendungen where s.stand == "zugestellt" {
            let zeiten = s.ereignisse.compactMap(\.zeit)
            guard let a = zeiten.min(), let b = zeiten.max(), b > a else { continue }
            dauer[s.dienst, default: []].append(b.timeIntervalSince(a) / 86400)
        }
        laufzeit = dauer.map { ($0.key, $0.value.reduce(0, +) / Double($0.value.count)) }.sorted { $0.tage < $1.tage }
    }
}

extension HomeAssistant {
    /// Archiv der letzten zwei Jahre (nur Pakete)
    public func archiv() async throws -> [ArchivEintrag] {
        let k = konto.isEmpty ? "" : "?konto=" + (konto.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        let d = try await anfrage("/api/briefankuendigung/archiv" + k)
        return (JSON.lesen(d)?["eintraege"]?.liste ?? []).compactMap { e in
            guard let ms = e["datum"]?.zahl else { return nil }
            return ArchivEintrag(datum: Date(timeIntervalSince1970: ms / 1000), absender: e["absender"]?.text ?? "",
                                 paket: e["art"]?.text == "paket", dienst: e["dienst"]?.text ?? "")
        }
    }
}
