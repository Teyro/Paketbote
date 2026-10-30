import Foundation

/// Rücksendefristen der großen Shops (Tage ab Zustellung; ohne Gewähr – die AGB des Shops gelten).
/// Gleiche Liste wie in der Home-Assistant-Integration (pakete.RUECKGABE_TAGE).
public enum Rueckgabe {
    public static let tage: [(shop: String, tage: Int)] = [
        ("zalando", 100), ("about you", 100), ("aboutyou", 100), ("ikea", 365), ("decathlon", 365), ("tchibo", 30), ("otto", 30),
        ("amazon", 30), ("h&m", 30), ("hm.com", 30), ("mediamarkt", 30), ("media markt", 30), ("saturn", 30), ("thalia", 14), ("lidl", 30),
        ("bonprix", 30), ("baur", 30), ("galeria", 30), ("esprit", 30), ("c&a", 30), ("zara", 30), ("mango", 30), ("asos", 28), ("shein", 45),
        ("temu", 90), ("apple", 14), ("notebooksbilliger", 30), ("alternate", 14), ("cyberport", 14), ("conrad", 30), ("douglas", 30),
        ("flaconi", 30),
    ]

    public static func frist(shop: String, dienst: String, zugestellt: Date, kalender: Calendar = .current) -> Date? {
        let s = shop.lowercased()
        guard let n = tage.first(where: { s.contains($0.shop) })?.tage ?? (dienst == "amazon" ? 30 : nil) else { return nil }
        return kalender.date(byAdding: .day, value: n, to: kalender.startOfDay(for: zugestellt))
    }
}

extension Texte {
    /// "2026-11-07" → Datum (Tagesbeginn)
    public static func tagAus(_ iso: String, kalender: Calendar = .current) -> Date? {
        let t = iso.split(separator: "-").compactMap { Int($0) }
        guard t.count == 3 else { return nil }
        return kalender.date(from: DateComponents(year: t[0], month: t[1], day: t[2]))
    }

    /// „7.11.“ bzw. „Fr 7.11.“ für die nächsten Tage
    public static func kurzTag(_ d: Date, jetzt: Date = Date(), kalender: Calendar = .current) -> String {
        let tage = kalender.dateComponents([.day], from: kalender.startOfDay(for: jetzt), to: kalender.startOfDay(for: d)).day ?? 99
        let tm = "\(kalender.component(.day, from: d)).\(kalender.component(.month, from: d))."
        if tage == 0 { return T("heute") }
        if tage == 1 { return T("morgen") }
        return tage > 1 && tage < 7 ? wochentag(d, kalender: kalender) + " " + tm : tm
    }
}

extension Dienst {
    /// Zustellung umleiten (Wunschnachbar, Ablageort, Filiale) beim Dienst
    public static func paketsteuerung(_ dienst: String, _ nummer: String) -> URL? {
        let n = nummer.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        switch dienst {
        case "hermes": return URL(string: "https://www.myhermes.de/empfangen/zustelloptionen/")
        case "dpd": return URL(string: "https://my.dpd.de/redirect.aspx?action=1&pno=\(n)")
        case "amazon": return URL(string: "https://www.amazon.de/gp/css/order-history")
        default: return verfolgen(dienst, nummer)
        }
    }
}
