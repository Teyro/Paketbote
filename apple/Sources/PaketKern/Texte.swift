import Foundation

/// Texte für Listen, Widgets, Siri und Mitteilungen
public enum Texte {
    public static func isoTag(_ d: Date, kalender: Calendar = .current) -> String {
        let k = kalender.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", k.year ?? 0, k.month ?? 0, k.day ?? 0)
    }

    static func wochentag(_ d: Date, kalender: Calendar) -> String {
        [T("So"), T("Mo"), T("Di"), T("Mi"), T("Do"), T("Fr"), T("Sa")][kalender.component(.weekday, from: d) - 1]
    }

    /// Stand in Worten: „kommt morgen, 10:00–13:00“, „voraussichtlich Fr 23.10.“, „zur Abholung bereit“, „zugestellt“
    public static func stand(_ s: Sendung, jetzt: Date = Date(), kalender: Calendar = .current) -> String {
        if s.stand == "zugestellt" { return T("zugestellt") }
        if s.erledigt { return T("angekommen") }
        if s.stand == "abholbereit" { return T("zur Abholung bereit") }
        let f = s.zeitfenster.isEmpty ? "" : ", " + s.zeitfenster
        if let d = s.erwartetTag(kalender: kalender) {
            let tage = kalender.dateComponents([.day], from: kalender.startOfDay(for: jetzt), to: d).day ?? 0
            if tage == 0 { return T("kommt heute") + f }
            if tage == 1 { return T("kommt morgen") + f }
            let tm = "\(kalender.component(.day, from: d)).\(kalender.component(.month, from: d))."
            if tage < 0 { return s.stand == "heute" ? T("kommt heute") + f : T("überfällig seit %1", tm) }
            return T("voraussichtlich %1", tage < 7 ? wochentag(d, kalender: kalender) + " " + tm : tm) + f
        }
        if s.stand == "heute" { return T("kommt heute") + f }
        if s.problem { return T("Problem bei der Zustellung") }
        return s.ereignisse.isEmpty ? T("angekündigt") : T("unterwegs")
    }

    /// Zweite Zeile: Stand · Kundenkonto (bzw. Postfach)
    public static func zeile(_ s: Sendung, jetzt: Date = Date(), mitKonto: Bool = false, kalender: Calendar = .current) -> String {
        var teile = [stand(s, jetzt: jetzt, kalender: kalender)]
        if !s.kundenkonto.isEmpty { teile.append(s.kundenkonto) } else if mitKonto && !s.kontoName.isEmpty { teile.append(s.kontoName) }
        return teile.joined(separator: " · ")
    }

    /// „1 Paket“ / „3 Pakete“
    public static func anzahl(_ n: Int) -> String { n == 1 ? T("1 Paket") : T("%1 Pakete", "\(n)") }

    /// Kopf: „3 Pakete unterwegs“ bzw. „Keine Pakete unterwegs“
    public static func titel(_ aktiv: [Sendung]) -> String {
        aktiv.isEmpty ? T("Keine Pakete unterwegs") : T("%1 unterwegs", anzahl(aktiv.count))
    }

    /// Für Siri und Mitteilungen: „Heute kommen 2 Pakete: Laufschuhe (Hermes) und Kindle (Amazon).“
    public static func heuteSatz(_ g: Gruppen) -> String {
        let h = g.heute.filter { $0.stand != "abholbereit" }, a = g.heute.filter { $0.stand == "abholbereit" }
        func liste(_ l: [Sendung]) -> String {
            let n = l.map { "\($0.titel) (\($0.dienstName))" }
            return n.count <= 1 ? (n.first ?? "") : n.dropLast().joined(separator: ", ") + " " + T("und") + " " + n.last!
        }
        var saetze: [String] = []
        if h.count == 1 { saetze.append(T("Heute kommt ein Paket: %1.", liste(h))) }
        if h.count > 1 { saetze.append(T("Heute kommen %1 Pakete: %2.", "\(h.count)", liste(h))) }
        if a.count == 1 { saetze.append(T("Zur Abholung bereit: %1.", liste(a))) }
        if a.count > 1 { saetze.append(T("%1 Pakete liegen zur Abholung bereit: %2.", "\(a.count)", liste(a))) }
        if saetze.isEmpty {
            saetze.append(g.unterwegs.isEmpty ? T("Heute kommt kein Paket, und es ist auch keins unterwegs.")
                                              : T("Heute kommt kein Paket. Unterwegs: %1.", anzahl(g.unterwegs.count)))
        }
        return saetze.joined(separator: " ")
    }

    /// „vor 5 min“, „vor 3 h“, „gestern“, „Di 20.10.“
    public static func vor(_ d: Date, jetzt: Date = Date(), kalender: Calendar = .current) -> String {
        let s = jetzt.timeIntervalSince(d)
        if s < 60 { return T("gerade eben") }
        if s < 3600 { return T("vor %1 min", "\(Int(s / 60))") }
        if kalender.isDate(d, inSameDayAs: jetzt) { return T("vor %1 h", "\(Int(s / 3600))") }
        if let g = kalender.date(byAdding: .day, value: -1, to: jetzt), kalender.isDate(d, inSameDayAs: g) { return T("gestern") }
        return wochentag(d, kalender: kalender) + " \(kalender.component(.day, from: d)).\(kalender.component(.month, from: d))."
    }

    /// Zeit eines Ereignisses: „heute 07:12“, „gestern 18:00“, „Di 20.10. 18:00“
    public static func ereigniszeit(_ d: Date?, jetzt: Date = Date(), kalender: Calendar = .current) -> String {
        guard let d else { return "" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = kalender.timeZone
        let uhr = f.string(from: d)
        if kalender.isDate(d, inSameDayAs: jetzt) { return T("heute %1", uhr) }
        if let g = kalender.date(byAdding: .day, value: -1, to: jetzt), kalender.isDate(d, inSameDayAs: g) { return T("gestern %1", uhr) }
        return wochentag(d, kalender: kalender) + " \(kalender.component(.day, from: d)).\(kalender.component(.month, from: d)). " + uhr
    }

    /// "homeassistant.local:8123" → "http://homeassistant.local:8123" (ohne / am Ende)
    public static func adresse(_ a: String) -> String {
        var s = a.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("/") { s.removeLast() }
        if !s.isEmpty && !s.contains("://") { s = "http://" + s }
        return s
    }

    /// Mitteilung, wenn sich der Stand einer Sendung ändert (nil = nichts Meldenswertes)
    public static func mitteilung(alt: Sendung?, neu: Sendung) -> (titel: String, text: String)? {
        let text = neu.titel + " (\(neu.dienstName))"
        if neu.problem && !(alt?.problem ?? false) { return (T("⚠️ Problem mit der Sendung"), text + (neu.statusText.isEmpty ? "" : " – " + neu.statusText)) }
        guard let alt, alt.stand != neu.stand, !neu.erledigt else { return nil }
        switch neu.stand {
        case "heute": return (T("📦 Kommt heute"), text)
        case "abholbereit": return (T("📦 Zur Abholung bereit"), text)
        case "zugestellt": return (T("📦 Zugestellt"), text)
        default: return nil
        }
    }
}
