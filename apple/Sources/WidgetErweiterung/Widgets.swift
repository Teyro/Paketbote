import WidgetKit
import SwiftUI
import PaketKern

/// Widgets von Paketbote für Home-Bildschirm, Sperrbildschirm (iPhone) und Schreibtisch (Mac).
@main
struct PaketboteWidgets: WidgetBundle {
    init() { Sprache.laden() }
    var body: some Widget {
        PaketeWidget()
    }
}

struct Eintrag: TimelineEntry {
    let date: Date
    let daten: WidgetDaten
}

struct Anbieter: TimelineProvider {
    private func gespeichert() -> Eintrag {
        let u = Ablage.lesen()
        return Eintrag(date: Date(), daten: WidgetDaten(uebersicht: u, eingerichtet: u != nil || Ablage.zugang.eingerichtet))
    }

    func placeholder(in context: Context) -> Eintrag {
        Eintrag(date: Date(), daten: WidgetDaten(uebersicht: Uebersicht(sendungen: [
            Sendung(id: "a", absender: "Laufschuhe", dienst: "hermes", stand: "heute"),
            Sendung(id: "b", absender: "Kindle", dienst: "amazon", erwartet: Texte.isoTag(Date().addingTimeInterval(86400))),
        ]), eingerichtet: true))
    }

    func getSnapshot(in context: Context, completion: @escaping (Eintrag) -> Void) { completion(gespeichert()) }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Eintrag>) -> Void) {
        Task {
            var e = gespeichert()
            #if os(iOS)
            // Auf dem iPhone holt das Widget selbst (die App läuft ja meist nicht)
            let ha = Ablage.zugang
            if ha.eingerichtet, let u = try? await ha.laden() {
                Ablage.schreiben(u)
                e = Eintrag(date: Date(), daten: WidgetDaten(uebersicht: u, eingerichtet: true))
            }
            #endif
            // um Mitternacht neu (für „kommt heute“), sonst alle 30 Minuten
            let mitternacht = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
            completion(Timeline(entries: [e], policy: .after(min(Date().addingTimeInterval(1800), mitternacht))))
        }
    }
}

struct PaketeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "pakete", provider: Anbieter()) { e in
            WidgetInhalt(e: e)
        }
        .configurationDisplayName(T("Pakete"))
        .description(T("Deine Sendungen mit voraussichtlicher Zustellung."))
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular, .accessoryInline])
        #else
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        #endif
    }
}

struct WidgetInhalt: View {
    let e: Eintrag
    @Environment(\.widgetFamily) private var familie
    var body: some View {
        Group {
            switch familie {
            case .systemSmall: KleinesWidget(daten: e.daten)
            case .systemLarge, .systemExtraLarge: GrossesWidget(daten: e.daten)
            #if os(iOS)
            case .accessoryRectangular: RechteckWidget(daten: e.daten)
            case .accessoryCircular: RundWidget(daten: e.daten)
            case .accessoryInline: ZeilenWidget(daten: e.daten)
            #endif
            default: MittleresWidget(daten: e.daten)
            }
        }
        .containerBackground(for: .widget) { Color.clear.background(.background) }
    }
}
