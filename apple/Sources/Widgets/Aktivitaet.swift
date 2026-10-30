#if os(iOS)
import ActivityKit
import SwiftUI
import WidgetKit
import PaketKern

/// Live-Aktivität (Sperrbildschirm, Dynamic Island) für ein Paket, das heute kommt
struct PaketAktivitaet: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stand: String
        var standText: String
        var stufe: Int
        var zeitfenster: String
        var abholcode: String = ""
    }
    var id: String
    var titel: String
    var dienst: String
}

struct PaketAktivitaetWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PaketAktivitaet.self) { k in
            HStack(spacing: 12) {
                DienstLogo(dienst: k.attributes.dienst, groesse: 46)
                VStack(alignment: .leading, spacing: 4) {
                    Text(k.attributes.titel).font(.headline).lineLimit(1)
                    Text(k.state.standText).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    StufenBalken(stufe: k.state.stufe)
                }
                Spacer(minLength: 0)
                if !k.state.abholcode.isEmpty {
                    VStack(spacing: 0) {
                        Text(T("Abholcode")).font(.caption2).foregroundStyle(.secondary)
                        Text(k.state.abholcode).font(.system(size: 22, weight: .bold, design: .monospaced))
                    }
                }
            }
            .padding(14)
            .activityBackgroundTint(Color(.systemBackground).opacity(0.85))
            .widgetURL(URL(string: "paketbote://sendung/\(k.attributes.id)"))
        } dynamicIsland: { k in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { DienstLogo(dienst: k.attributes.dienst, groesse: 40) }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(k.attributes.titel).font(.headline).lineLimit(1)
                        Text(k.state.standText).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !k.state.abholcode.isEmpty { Text(k.state.abholcode).font(.system(size: 18, weight: .bold, design: .monospaced)) }
                }
                DynamicIslandExpandedRegion(.bottom) { StufenBalken(stufe: k.state.stufe).padding(.horizontal, 6) }
            } compactLeading: {
                Image(systemName: "shippingbox.fill").foregroundStyle(Color(Dienst.farben(k.attributes.dienst).hintergrund))
            } compactTrailing: {
                Text(!k.state.abholcode.isEmpty ? k.state.abholcode : k.state.stand == "abholbereit" ? T("Abholen") : k.state.zeitfenster.isEmpty ? T("Heute") : k.state.zeitfenster)
                    .font(.caption2.weight(.semibold))
            } minimal: {
                Image(systemName: "shippingbox.fill")
            }
            .widgetURL(URL(string: "paketbote://sendung/\(k.attributes.id)"))
        }
    }
}

/// Vier Schritte als Balken (ohne Sendung – für die Live-Aktivität)
struct StufenBalken: View {
    let stufe: Int
    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...4, id: \.self) { i in
                Capsule().fill(i <= stufe ? Color.accentColor : Color.primary.opacity(0.15)).frame(height: 5)
            }
        }
    }
}
#endif
