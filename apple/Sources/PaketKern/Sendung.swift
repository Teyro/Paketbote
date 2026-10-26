import Foundation

/// Ein Eintrag im Verlauf einer Sendung („Die Sendung ist im Verteilzentrum.“, Ketzin, 20.10. 18:00)
public struct Ereignis: Codable, Hashable, Sendable, Identifiable {
    public var zeit: Date?
    public var text: String
    public var ort: String
    public var id: String { "\(zeit?.timeIntervalSince1970 ?? 0)|\(text)" }

    public init(zeit: Date?, text: String, ort: String = "") {
        self.zeit = zeit; self.text = text; self.ort = ort
    }
}

/// Eine Sendung, wie sie die Home-Assistant-Integration „Briefankündigung“ (ab 1.4) liefert.
public struct Sendung: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    /// Zeit der letzten Meldung
    public var datum: Date
    /// Shop bzw. Artikel (bei Amazon)
    public var absender: String
    /// Eigener Name (umbenannt)
    public var name: String
    public var nummer: String
    /// dhl, hermes, dpd, gls, ups, amazon
    public var dienst: String
    public var dienstName: String
    /// unterwegs | heute | abholbereit | zugestellt
    public var stand: String
    /// "2026-10-23" oder ""
    public var erwartet: String
    public var zeitfenster: String
    public var kundenkonto: String
    public var verfolgen: String
    public var manuell: Bool
    public var statusText: String
    public var problem: Bool
    public var erledigt: Bool
    public var kontoId: String
    public var kontoName: String
    public var ereignisse: [Ereignis]

    public init(id: String, datum: Date = Date(), absender: String = "", name: String = "", nummer: String = "", dienst: String = "dhl",
                dienstName: String = "", stand: String = "unterwegs", erwartet: String = "", zeitfenster: String = "", kundenkonto: String = "",
                verfolgen: String = "", manuell: Bool = false, statusText: String = "", problem: Bool = false, erledigt: Bool = false,
                kontoId: String = "", kontoName: String = "", ereignisse: [Ereignis] = []) {
        self.id = id; self.datum = datum; self.absender = absender; self.name = name; self.nummer = nummer; self.dienst = dienst
        self.dienstName = dienstName.isEmpty ? Dienst.name(dienst) : dienstName; self.stand = stand; self.erwartet = erwartet
        self.zeitfenster = zeitfenster; self.kundenkonto = kundenkonto; self.verfolgen = verfolgen; self.manuell = manuell
        self.statusText = statusText; self.problem = problem; self.erledigt = erledigt; self.kontoId = kontoId; self.kontoName = kontoName
        self.ereignisse = ereignisse
    }

    /// Was angezeigt wird: eigener Name, sonst Absender, sonst die Nummer
    public var titel: String {
        if !name.isEmpty { return name }
        if !absender.isEmpty { return absender }
        return nummer.isEmpty ? T("Paket") : nummer
    }

    /// Zugestellt oder abgehakt
    public var fertig: Bool { stand == "zugestellt" || erledigt }

    /// Kommt heute: Stand „heute“/„abholbereit“ oder heute erwartet
    public func kommtHeute(jetzt: Date = Date(), kalender: Calendar = .current) -> Bool {
        !fertig && (stand == "heute" || stand == "abholbereit" || (!erwartet.isEmpty && erwartet == Texte.isoTag(jetzt, kalender: kalender)))
    }

    /// Fortschritt 1…4: angekündigt/unterwegs · in Zustellung bzw. abholbereit · zugestellt
    public var stufe: Int {
        switch stand {
        case "zugestellt": 4
        case "heute", "abholbereit": 3
        default: ereignisse.isEmpty ? 1 : 2
        }
    }

    /// Termin als Datum (Tagesbeginn) oder nil
    public func erwartetTag(kalender: Calendar = .current) -> Date? {
        let t = erwartet.split(separator: "-").compactMap { Int($0) }
        guard t.count == 3 else { return nil }
        return kalender.date(from: DateComponents(year: t[0], month: t[1], day: t[2]))
    }

    /// Link zur Sendungsverfolgung (von der Integration; sonst aus Dienst und Nummer)
    public var verfolgenURL: URL? {
        if let u = URL(string: verfolgen), u.scheme == "https" { return u }
        return Dienst.verfolgen(dienst, nummer)
    }
}

/// Ein Postfach (Konto) der Integration
public struct Konto: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var fehler: String
    public var stand: Date?
    public var siebzehn: Bool
    public var siebzehnRest: Int?
    public var dhlLive: Bool

    public init(id: String, name: String, fehler: String = "", stand: Date? = nil, siebzehn: Bool = false, siebzehnRest: Int? = nil, dhlLive: Bool = false) {
        self.id = id; self.name = name; self.fehler = fehler; self.stand = stand; self.siebzehn = siebzehn; self.siebzehnRest = siebzehnRest; self.dhlLive = dhlLive
    }
}

/// Alles, was Home Assistant liefert: Sendungen (nur Pakete) und Postfächer
public struct Uebersicht: Codable, Hashable, Sendable {
    public var sendungen: [Sendung]
    public var konten: [Konto]
    /// Wann die Integration zuletzt ins Postfach geschaut hat
    public var stand: Date?
    public var fehler: String
    /// Version der Schnittstelle (4 = mit Verlauf, 17TRACK, Umbenennen)
    public var version: Int
    public var geholt: Date

    public init(sendungen: [Sendung] = [], konten: [Konto] = [], stand: Date? = nil, fehler: String = "", version: Int = 0, geholt: Date = Date()) {
        self.sendungen = sendungen; self.konten = konten; self.stand = stand; self.fehler = fehler; self.version = version; self.geholt = geholt
    }

    private static func zeit(_ j: JSON?) -> Date? {
        guard let ms = j?.zahl, ms > 0 else { return nil }
        return Date(timeIntervalSince1970: ms / 1000)
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// ISO-Zeit aus DHL bzw. 17TRACK („2026-10-21T07:12:00+02:00“, auch ohne Zeitzone)
    public static func isoZeit(_ s: String) -> Date? {
        if let d = iso.date(from: s) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for muster in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            f.dateFormat = muster
            if let d = f.date(from: String(s.prefix(muster.replacingOccurrences(of: "'", with: "").count))) { return d }
        }
        return nil
    }

    /// Antwort von GET /api/briefankuendigung/briefe – nur die Pakete
    public static func aus(_ j: JSON, geholt: Date = Date()) -> Uebersicht? {
        guard let briefe = j["briefe"]?.liste else { return nil }
        let sendungen: [Sendung] = briefe.compactMap { b in
            guard b["art"]?.text == "paket", let id = b["id"]?.text, let d = zeit(b["datum"]) else { return nil }
            let ereignisse: [Ereignis] = (b["ereignisse"]?.liste ?? []).compactMap { e in
                guard let text = e["text"]?.text, !text.isEmpty else { return nil }
                return Ereignis(zeit: e["zeit"]?.text.flatMap(isoZeit), text: text, ort: e["ort"]?.text ?? "")
            }
            let dienst = b["dienst"]?.text ?? "dhl"
            return Sendung(id: id, datum: d, absender: b["absender"]?.text ?? "", name: b["name"]?.text ?? "", nummer: b["sendung"]?.text ?? "",
                           dienst: dienst, dienstName: b["dienst_name"]?.text ?? "", stand: b["stand"]?.text ?? "unterwegs",
                           erwartet: b["erwartet"]?.text ?? "", zeitfenster: b["zeitfenster"]?.text ?? "", kundenkonto: b["kundenkonto"]?.text ?? "",
                           verfolgen: b["verfolgen"]?.text ?? "", manuell: b["manuell"]?.bool ?? false, statusText: b["status_text"]?.text ?? "",
                           problem: b["problem"]?.bool ?? false, erledigt: b["erledigt"]?.bool ?? false,
                           kontoId: b["konto"]?.text ?? "", kontoName: b["konto_name"]?.text ?? "", ereignisse: ereignisse)
        }
        let konten: [Konto] = (j["konten"]?.liste ?? []).compactMap { k in
            guard let id = k["id"]?.text else { return nil }
            return Konto(id: id, name: k["name"]?.text ?? id, fehler: k["fehler"]?.text ?? "", stand: zeit(k["stand"]),
                         siebzehn: k["siebzehn"]?.bool ?? false, siebzehnRest: k["siebzehn_rest"]?.zahl.map { Int($0) },
                         dhlLive: k["dhl_live"]?.bool ?? false)
        }
        return Uebersicht(sendungen: sendungen, konten: konten, stand: zeit(j["stand"]), fehler: j["fehler"]?.text ?? "",
                          version: Int(j["version"]?.zahl ?? 1), geholt: geholt)
    }

    /// Nur ein Postfach (Name oder ID; "" = alle)
    public func nur(konto: String) -> Uebersicht {
        let k = konto.trimmingCharacters(in: .whitespaces).lowercased()
        guard !k.isEmpty else { return self }
        var u = self
        u.sendungen = sendungen.filter { $0.kontoId.lowercased() == k || $0.kontoName.lowercased() == k }
        return u
    }

    public var mehrereKonten: Bool { konten.count > 1 }
}

/// Sendungen für die Anzeige: Heute · Unterwegs (nach Termin) · Zugestellt
public struct Gruppen: Equatable, Sendable {
    public var heute: [Sendung] = []
    public var unterwegs: [Sendung] = []
    public var zugestellt: [Sendung] = []
    public var aktiv: [Sendung] { heute + unterwegs }

    public init() {}

    /// zugestellte nur der letzten `tage` Tage
    public init(_ sendungen: [Sendung], jetzt: Date = Date(), kalender: Calendar = .current, tage: Int = 14) {
        let grenze = jetzt.addingTimeInterval(-Double(tage) * 86400)
        for s in sendungen {
            if s.fertig { if s.datum >= grenze { zugestellt.append(s) } }
            else if s.kommtHeute(jetzt: jetzt, kalender: kalender) { heute.append(s) }
            else { unterwegs.append(s) }
        }
        let nachTermin: (Sendung, Sendung) -> Bool = { a, b in
            let x = a.erwartet.isEmpty ? "9999" : a.erwartet, y = b.erwartet.isEmpty ? "9999" : b.erwartet
            return x != y ? x < y : a.datum > b.datum
        }
        // Heute: abholbereit zuletzt (liegt ja schon da), sonst nach Termin
        heute.sort { a, b in (a.stand == "abholbereit") != (b.stand == "abholbereit") ? b.stand == "abholbereit" : nachTermin(a, b) }
        unterwegs.sort(by: nachTermin)
        zugestellt.sort { $0.datum > $1.datum }
    }
}
