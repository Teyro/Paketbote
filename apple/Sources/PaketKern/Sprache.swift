import Foundation

/// Übersetzungen: Schlüssel ist der deutsche Text, die Tabellen liegen als JSON in i18n/<sprache>.json
/// (gemeinsam mit dem Plasma-Widget).
public enum Sprache {
    public static let verfuegbar = ["de", "en"]
    nonisolated(unsafe) public private(set) static var code = "de"
    nonisolated(unsafe) static var tabelle: [String: String] = [:]
    /// Dezimaltrennzeichen der Sprache (für Zahlen wie "21,5 °C")
    nonisolated(unsafe) public private(set) static var dezimal = ","

    /// Passende Sprache aus den Systemeinstellungen wählen und die Tabelle aus dem Bundle laden
    public static func laden(bundle: Bundle = .main) {
        let wunsch = Locale.preferredLanguages.map { String($0.prefix(2)) }.first { verfuegbar.contains($0) } ?? "en"
        code = wunsch
        dezimal = ["de", "es", "fr", "bn"].contains(wunsch) ? "," : "."
        tabelle = [:]
        guard wunsch != "de",
              let url = bundle.url(forResource: wunsch, withExtension: "json", subdirectory: "i18n") ?? bundle.url(forResource: wunsch, withExtension: "json"),
              let daten = try? Data(contentsOf: url),
              let t = try? JSONDecoder().decode([String: String].self, from: daten) else { return }
        tabelle = t
    }

    /// Zahl mit Einheit bei Rechts-nach-links-Schrift isolieren (sonst wird aus "21 °C" "C° 21")
    public static func iso(_ s: String) -> String {
        code == "ar" && s != "–" ? "\u{2066}" + s + "\u{2069}" : s
    }

    public static func setzen(code: String, tabelle: [String: String], dezimal: String) {
        self.code = code
        self.tabelle = tabelle
        self.dezimal = dezimal
    }
}

/// Text übersetzen; %1, %2 … werden durch die Werte ersetzt
public func T(_ text: String, _ werte: String...) -> String {
    var s = Sprache.tabelle[text].flatMap { $0.isEmpty ? nil : $0 } ?? text
    for (i, w) in werte.enumerated().reversed() { s = s.replacingOccurrences(of: "%\(i + 1)", with: w) }
    return s
}
