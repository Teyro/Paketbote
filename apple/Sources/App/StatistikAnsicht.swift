import SwiftUI
import Charts
import PaketKern

/// Statistik: Pakete pro Monat, häufigste Shops, Dienste, Laufzeiten
struct StatistikAnsicht: View {
    let kern: Kern
    @Environment(\.dismiss) private var schliessen
    @State private var archiv: [ArchivEintrag] = []
    @State private var laedt = true

    var body: some View {
        let st = Statistik(archiv: archiv, sendungen: kern.alle)
        List {
            Section {
                Chart(st.monate) { m in
                    BarMark(x: .value(T("Monat"), m.name), y: .value(T("Anzahl"), m.anzahl))
                        .foregroundStyle(by: .value(T("Art"), T("Pakete")))
                        .cornerRadius(4)
                    BarMark(x: .value(T("Monat"), m.name), y: .value(T("Anzahl"), m.briefe))
                        .foregroundStyle(by: .value(T("Art"), T("Briefe")))
                        .cornerRadius(4)
                }
                .chartForegroundStyleScale([T("Pakete"): Color.accentColor, T("Briefe"): Color.orange])
                .chartXAxis { AxisMarks { _ in AxisValueLabel() } }
                .frame(height: 180)
                .padding(.vertical, 6)
            } header: {
                Text(T("Post pro Monat"))
            } footer: {
                Text(laedt ? T("Lade das Archiv …") : T("%1 und %2 in den letzten zwei Jahren.", Texte.anzahl(st.gesamt), Texte.briefe(st.briefeGesamt)))
            }
            if !st.shops.isEmpty {
                Section(T("Häufigste Absender")) {
                    ForEach(Array(st.shops.enumerated()), id: \.offset) { _, s in
                        LabeledContent(s.name, value: "\(s.anzahl)")
                    }
                }
            }
            if !st.dienste.isEmpty {
                Section(T("Paketdienste")) {
                    ForEach(Array(st.dienste.enumerated()), id: \.offset) { _, d in
                        HStack {
                            DienstLogo(dienst: d.dienst, groesse: 28)
                            Text(Dienst.name(d.dienst))
                            Spacer()
                            Text("\(d.anzahl)").foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
            }
            if !st.laufzeit.isEmpty {
                Section {
                    ForEach(Array(st.laufzeit.enumerated()), id: \.offset) { _, l in
                        LabeledContent(Dienst.name(l.dienst), value: T("%1 Tage", String(format: "%.1f", l.tage)))
                    }
                } header: {
                    Text(T("Durchschnittliche Laufzeit"))
                } footer: {
                    Text(T("Von der ersten Station bis zur Zustellung – aus Sendungen mit Verlauf."))
                }
            }
        }
        .navigationTitle(T("Statistik"))
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(T("Fertig")) { schliessen() } } }
        .task {
            if kern.einstellungen.eingerichtet { archiv = (try? await kern.ha.archiv()) ?? [] }
            laedt = false
        }
    }
}
