import Foundation

/// Abgleich zwischen den Geräten über Home Assistant (ab Integration 1.8): Jedes Gerät gibt seine selbst verfolgten
/// Sendungen samt Stand weiter, alle anderen bekommen sie beim nächsten Laden.
public enum Abgleich {
    /// Direkt verfolgte Sendungen, die Home Assistant noch nicht (oder mit älterem Stand) kennt.
    /// gesendet: Nummer → zuletzt geschickter Stand (nicht zweimal dasselbe schicken)
    public static func offen(ha: [Sendung], direkt: [Sendung], gesendet: [String: String]) -> [Sendung] {
        direkt.filter { d in
            guard !d.nummer.isEmpty, gesendet[d.nummer] != d.signatur else { return false }
            guard let h = ha.first(where: { $0.nummer.uppercased() == d.nummer }) else { return true }
            return h.stufe < d.stufe || h.ereignisse.count < d.ereignisse.count
                || (d.erledigt && !h.erledigt) || (d.ruecksendung && !h.ruecksendung)
        }
    }
}

extension Sendung {
    /// Kurzform des Stands, um Doppeltes zu erkennen
    public var signatur: String { "\(stand)|\(ereignisse.count)|\(erledigt)|\(ruecksendung)" }

    /// Was dieses Gerät über die Sendung weiß – so, wie Home Assistant es erwartet
    public var standInfo: [String: Any] {
        let iso = ISO8601DateFormatter()
        return ["stand": stand, "text": statusText, "erwartet": erwartet, "zeitfenster": zeitfenster, "problem": problem,
                "ruecksendung": ruecksendung, "erledigt": erledigt,
                "ereignisse": ereignisse.prefix(40).map { ["zeit": $0.zeit.map { iso.string(from: $0) } ?? "", "text": $0.text, "ort": $0.ort] }]
    }
}
