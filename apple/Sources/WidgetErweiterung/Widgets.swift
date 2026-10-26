import WidgetKit
import SwiftUI
import AppIntents
import PaketKern

/// Widgets von Paketbote für Home-Bildschirm, Sperrbildschirm (iPhone) und Schreibtisch (Mac).
@main
struct PaketboteWidgets: WidgetBundle {
    init() { Sprache.laden() }
    var body: some Widget {
        PaketeWidget()
        #if os(iOS)
        PaketAktivitaetWidget()
        #endif
    }
}

/// Einstellungen des Widgets (lange drücken → „Widget bearbeiten“): eigener Zugang zu Home Assistant.
/// Nötig, wenn die App ihn nicht teilen kann (keine App-Gruppe nach dem Neu-Signieren, z. B. mit Signulous).
struct WidgetZugang: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Paketbote"
    static let description = IntentDescription("Home Assistant für dieses Widget – nur nötig, wenn das Widget sonst nichts zeigt.")

    @Parameter(title: "Home-Assistant-Adresse") var adresse: String?
    @Parameter(title: "Zugriffstoken") var token: String?
    @Parameter(title: "Postfach (leer = alle)") var konto: String?

    init() {}
}

struct Eintrag: TimelineEntry {
    let date: Date
    let daten: WidgetDaten
}

struct Zeitleiste: AppIntentTimelineProvider {
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

    func snapshot(for configuration: WidgetZugang, in context: Context) async -> Eintrag { gespeichert() }

    func timeline(for configuration: WidgetZugang, in context: Context) async -> Timeline<Eintrag> {
        var e = gespeichert()
        // Zugang: aus der App (App-Gruppe) oder aus den Einstellungen des Widgets
        var ha = Ablage.zugang
        if !ha.eingerichtet, let a = configuration.adresse, let t = configuration.token, !a.isEmpty, !t.isEmpty {
            ha = HomeAssistant(adresse: a, token: t, konto: configuration.konto ?? "")
        }
        if ha.eingerichtet, var u = try? await ha.laden() {
            // direkt verfolgte Sendungen aus dem letzten Stand der App behalten
            let direkt = (e.daten.uebersicht?.sendungen ?? []).filter { $0.quelle == "direkt" }
            u.sendungen = zusammenfuehren(ha: u.sendungen, direkt: direkt)
            e = Eintrag(date: Date(), daten: WidgetDaten(uebersicht: u, eingerichtet: true))
        }
        // um Mitternacht neu (für „kommt heute“), sonst alle 30 Minuten
        let mitternacht = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        return Timeline(entries: [e], policy: .after(min(Date().addingTimeInterval(1800), mitternacht)))
    }
}

struct PaketeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "pakete", intent: WidgetZugang.self, provider: Zeitleiste()) { e in
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
