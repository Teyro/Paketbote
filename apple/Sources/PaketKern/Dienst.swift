import Foundation

/// Paketdienste: Name, Farben, Nummern erkennen, Sendungsverfolgung
public enum Dienst {
    public static let alle = ["dhl", "hermes", "dpd", "gls", "ups", "amazon"]

    public static func name(_ d: String) -> String {
        ["dhl": "DHL", "hermes": "Hermes", "dpd": "DPD", "gls": "GLS", "ups": "UPS", "amazon": "Amazon"][d] ?? d.uppercased()
    }

    /// Hintergrund- und Schriftfarbe als RGB (0…1)
    public static func farben(_ d: String) -> (hintergrund: (Double, Double, Double), schrift: (Double, Double, Double)) {
        switch d {
        case "dhl": ((1, 0.8, 0), (0.83, 0.02, 0.07))
        case "hermes": ((0, 0.57, 0.8), (1, 1, 1))
        case "dpd": ((0.86, 0, 0.2), (1, 1, 1))
        case "gls": ((0.06, 0.2, 0.48), (1, 0.85, 0))
        case "ups": ((0.25, 0.16, 0.1), (1, 0.71, 0))
        case "amazon": ((0.14, 0.18, 0.24), (1, 0.6, 0))
        default: ((0.72, 0.52, 0.3), (1, 1, 1))
        }
    }

    /// Dienst an der Nummer erkennen ("" = nicht eindeutig, z. B. 14 Ziffern bei Hermes und DPD)
    public static func vonNummer(_ nummer: String) -> String {
        let n = nummer.replacingOccurrences(of: " ", with: "").uppercased()
        func passt(_ muster: String) -> Bool { n.range(of: "^(" + muster + ")$", options: .regularExpression) != nil }
        if passt("TBA[0-9]{9,14}|[0-9]{3}-[0-9]{7}-[0-9]{7}") { return "amazon" }
        if passt("JJD[0-9]{12,20}|00[0-9]{18}|[0-9]{20}|[0-9]{12}") { return "dhl" }
        if passt("H[0-9A-Z]{19}") { return "hermes" }
        if passt("1Z[0-9A-Z]{16}") { return "ups" }
        return ""
    }

    /// Sieht der Text wie eine Sendungsnummer aus? (für „Aus der Zwischenablage“)
    public static func nummerIn(_ text: String) -> String? {
        let muster = "TBA[0-9]{9,14}|[0-9]{3}-[0-9]{7}-[0-9]{7}|JJD[0-9]{12,20}|1Z[0-9A-Z]{16}|H[0-9A-Z]{19}|[0-9]{11,20}"
        guard let r = text.uppercased().range(of: muster, options: .regularExpression) else { return nil }
        return String(text.uppercased()[r])
    }

    public static func verfolgen(_ dienst: String, _ nummer: String) -> URL? {
        guard !nummer.isEmpty, let n = nummer.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        let adresse: String
        switch dienst {
        case "hermes": adresse = "https://www.myhermes.de/empfangen/sendungsverfolgung/sendungsinformation#\(n)"
        case "dpd": adresse = "https://tracking.dpd.de/status/de_DE/parcel/\(n)"
        case "gls": adresse = "https://gls-group.com/DE/de/paketverfolgung?match=\(n)"
        case "ups": adresse = "https://www.ups.com/track?loc=de_DE&tracknum=\(n)"
        case "amazon": adresse = "https://track.amazon.de/tracking/\(n)"
        default: adresse = "https://www.dhl.de/de/privatkunden/pakete-empfangen/verfolgen.html?piececode=\(n)"
        }
        return URL(string: adresse)
    }
}
