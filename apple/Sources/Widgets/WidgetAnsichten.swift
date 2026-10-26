import SwiftUI
import WidgetKit
import PaketKern

// Ansichten der Widgets – auch in der App für die Vorschau-Bilder benutzt.

/// Was ein Widget zeigt
struct WidgetDaten {
    var uebersicht: Uebersicht?
    var eingerichtet: Bool
    var jetzt = Date()

    var gruppen: Gruppen { Gruppen(uebersicht?.sendungen ?? [], jetzt: jetzt) }
    var aktiv: [Sendung] { gruppen.aktiv }

    static var leer: WidgetDaten { WidgetDaten(uebersicht: nil, eingerichtet: false) }
}

func sendungsLink(_ s: Sendung) -> URL { URL(string: "paketbote://sendung/\(s.id)")! }

/// Kopf: Symbol, „3 Pakete unterwegs“, rechts „2 heute“
struct WidgetKopf: View {
    let daten: WidgetDaten
    var kompakt = false
    var body: some View {
        let g = daten.gruppen
        HStack(spacing: 5) {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(Color.accentColor)
                .font(.system(size: kompakt ? 12 : 14, weight: .semibold))
            Text(kompakt ? (g.aktiv.isEmpty ? T("Pakete") : T("%1 unterwegs", "\(g.aktiv.count)")) : Texte.titel(g.aktiv))
                .font(.system(size: kompakt ? 12 : 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            if !g.heute.isEmpty {
                Text(T("%1 heute", "\(g.heute.count)"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 1.5)
                    .background(Color.accentColor, in: Capsule())
                    .fixedSize()
            }
        }
    }
}

/// Hinweis, wenn nichts unterwegs ist oder etwas fehlt
struct WidgetLeer: View {
    let daten: WidgetDaten
    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            Image(systemName: !daten.eingerichtet ? "gearshape" : "shippingbox")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.secondary)
            Text(!daten.eingerichtet ? T("App öffnen und einrichten") : T("Keine Pakete unterwegs"))
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if let z = daten.gruppen.zugestellt.first {
                Text(T("Zuletzt: %1", z.titel)).font(.system(size: 10)).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Eine Zeile im Widget
struct WidgetZeile: View {
    let sendung: Sendung
    var logo: CGFloat = 30
    var jetzt = Date()
    var body: some View {
        HStack(spacing: 9) {
            DienstLogo(dienst: sendung.dienst, groesse: logo)
            VStack(alignment: .leading, spacing: 1) {
                Text(sendung.titel).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(Texte.zeile(sendung, jetzt: jetzt))
                    .font(.system(size: 11))
                    .foregroundStyle(standFarbe(sendung))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Klein: das nächste Paket
struct KleinesWidget: View {
    let daten: WidgetDaten
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetKopf(daten: daten, kompakt: true)
            if let s = daten.aktiv.first {
                Spacer(minLength: 0)
                DienstLogo(dienst: s.dienst, groesse: 42)
                Text(s.titel).font(.system(size: 14, weight: .bold)).lineLimit(2).minimumScaleFactor(0.8)
                Text(Texte.stand(s, jetzt: daten.jetzt))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(standFarbe(s))
                    .lineLimit(2)
                Fortschritt(sendung: s, hoehe: 4)
            } else {
                WidgetLeer(daten: daten)
            }
        }
        .widgetURL(daten.aktiv.first.map(sendungsLink))
    }
}

/// Mittel: bis zu drei Pakete
struct MittleresWidget: View {
    let daten: WidgetDaten
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            WidgetKopf(daten: daten)
            if daten.aktiv.isEmpty {
                WidgetLeer(daten: daten)
            } else {
                ForEach(daten.aktiv.prefix(3)) { s in
                    Link(destination: sendungsLink(s)) { WidgetZeile(sendung: s, jetzt: daten.jetzt) }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// Groß: Heute und Unterwegs, bis zu sieben Pakete
struct GrossesWidget: View {
    let daten: WidgetDaten
    var body: some View {
        let g = daten.gruppen
        VStack(alignment: .leading, spacing: 8) {
            WidgetKopf(daten: daten)
            if g.aktiv.isEmpty {
                WidgetLeer(daten: daten)
            } else {
                let heute = Array(g.heute.prefix(7)), spaeter = Array(g.unterwegs.prefix(max(0, 7 - heute.count)))
                if !heute.isEmpty {
                    ueberschrift(T("Heute"))
                    ForEach(heute) { s in Link(destination: sendungsLink(s)) { WidgetZeile(sendung: s, logo: 34, jetzt: daten.jetzt) } }
                }
                if !spaeter.isEmpty {
                    ueberschrift(T("Unterwegs"))
                    ForEach(spaeter) { s in Link(destination: sendungsLink(s)) { WidgetZeile(sendung: s, logo: 34, jetzt: daten.jetzt) } }
                }
                Spacer(minLength: 0)
                if g.aktiv.count > 7 {
                    Text(T("+ %1 weitere", "\(g.aktiv.count - 7)")).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func ueberschrift(_ t: String) -> some View {
        Text(t.uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
    }
}

#if os(iOS)
/// Sperrbildschirm: nächstes Paket
struct RechteckWidget: View {
    let daten: WidgetDaten
    var body: some View {
        if let s = daten.aktiv.first {
            VStack(alignment: .leading, spacing: 1) {
                Label(s.titel, systemImage: "shippingbox.fill").font(.headline).lineLimit(1)
                Text(Texte.stand(s, jetzt: daten.jetzt)).font(.caption).lineLimit(1)
                if daten.aktiv.count > 1 { Text(T("+ %1 weitere", "\(daten.aktiv.count - 1)")).font(.caption2).foregroundStyle(.secondary) }
            }
            .widgetURL(sendungsLink(s))
        } else {
            Label(daten.eingerichtet ? T("Keine Pakete unterwegs") : T("Paketbote einrichten"), systemImage: "shippingbox")
                .font(.caption)
        }
    }
}

/// Sperrbildschirm rund: Anzahl unterwegs, Ring = heute
struct RundWidget: View {
    let daten: WidgetDaten
    var body: some View {
        let g = daten.gruppen
        Gauge(value: Double(g.heute.count), in: 0...Double(max(1, g.aktiv.count))) {
            Image(systemName: "shippingbox.fill")
        } currentValueLabel: {
            Text("\(g.aktiv.count)")
        }
        .gaugeStyle(.accessoryCircular)
    }
}

/// Zeile über der Uhr: „2 Pakete heute“
struct ZeilenWidget: View {
    let daten: WidgetDaten
    var body: some View {
        let g = daten.gruppen
        Label(g.heute.isEmpty ? Texte.titel(g.aktiv) : T("%1 heute", Texte.anzahl(g.heute.count)), systemImage: "shippingbox.fill")
    }
}
#endif
