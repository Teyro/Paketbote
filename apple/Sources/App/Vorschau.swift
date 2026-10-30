import SwiftUI
import PaketKern

/// Testlauf für die Bildschirmfotos (GitHub Actions): `--vorschau` mit PB_ADRESSE, PB_TOKEN und
/// PB_ANSICHT = liste | detail | brief | statistik | hinzufuegen | einstellungen | widgets
struct Vorschau: View {
    @Bindable var kern: Kern
    private let ansicht = ProcessInfo.processInfo.environment["PB_ANSICHT"] ?? "liste"

    var body: some View {
        Group {
            if ansicht == "widgets" {
                WidgetGalerie(daten: WidgetDaten(uebersicht: kern.daten, eingerichtet: true))
            } else {
                Hauptansicht(kern: kern)
            }
        }
        .task {
            await kern.laden()
            try? await Task.sleep(for: .seconds(1))
            switch ansicht {
            case "detail": kern.auswahl = kern.gruppen.heute.first?.id ?? kern.gruppen.aktiv.first?.id
            case "brief": kern.auswahl = kern.briefGruppen.heute.first?.id
            case "statistik": kern.statistikOffen = true
            case "hinzufuegen": kern.hinzufuegenOffen = true
            case "einstellungen": kern.einstellungenOffen = true
            default: break
            }
            print("vorschau:", ansicht, "sendungen:", kern.daten?.sendungen.count ?? -1, "fehler:", kern.fehler)
        }
    }
}

/// Alle Widget-Größen nebeneinander (wie auf dem Home-Bildschirm)
struct WidgetGalerie: View {
    let daten: WidgetDaten

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    kachel(170, 170) { KleinesWidget(daten: daten) }
                    kachel(170, 170) { KleinesWidget(daten: .leer) }
                }
                kachel(356, 170) { MittleresWidget(daten: daten) }
                kachel(356, 376) { GrossesWidget(daten: daten) }
                #if os(iOS)
                HStack(spacing: 16) {
                    RechteckWidget(daten: daten).frame(width: 170, height: 72, alignment: .leading).padding(8)
                        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.white)
                    RundWidget(daten: daten).frame(width: 72, height: 72).padding(8)
                        .background(.black.opacity(0.75), in: Circle()).foregroundStyle(.white)
                }
                #endif
            }
            .padding(20)
        }
        .background(LinearGradient(colors: [.indigo.opacity(0.5), .teal.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func kachel<V: View>(_ b: CGFloat, _ h: CGFloat, @ViewBuilder inhalt: () -> V) -> some View {
        inhalt()
            .padding(14)
            .frame(width: b, height: h, alignment: .topLeading)
            .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
    }
}
