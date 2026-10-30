import SwiftUI
import PaketKern

/// Ein Brief: Umschlag groß, Absender, Tag, Angekommen, Erinnern, Teilen, Notiz
struct BriefDetail: View {
    let kern: Kern
    let brief: Brief
    @State private var notiz = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Umschlag(kern: kern, brief: brief, gross: true)
                    .aspectRatio(1.6, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                VStack(alignment: .leading, spacing: 6) {
                    if brief.wichtig { Etikett(text: T("Wichtig"), farbe: .red) }
                    Text(brief.titel).font(.title2.weight(.bold))
                    Text(Texte.brief(brief, mitKonto: kern.mehrereKonten))
                        .font(.headline)
                        .foregroundStyle(brief.heute() && !brief.erledigt ? Color.accentColor : .secondary)
                    Text(T("Angekündigt am %1", brief.datum.formatted(date: .complete, time: .shortened)))
                        .font(.callout).foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    Button { Task { await kern.briefErledigt(brief, !brief.erledigt) } } label: {
                        Label(brief.erledigt ? T("Doch nicht da") : T("Angekommen"), systemImage: brief.erledigt ? "arrow.uturn.backward" : "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Menu {
                        Button(T("Heute Abend")) { erinnern(0) }
                        Button(T("Morgen früh")) { erinnern(1) }
                        Button(T("In 3 Tagen")) { erinnern(3) }
                        Button(T("In einer Woche")) { erinnern(7) }
                    } label: {
                        Label(T("Erinnern"), systemImage: "bell").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
                VStack(alignment: .leading, spacing: 8) {
                    Text(T("Notiz")).font(.headline)
                    TextField(T("z. B. Steuerbescheid, Frist 30.11."), text: $notiz, axis: .vertical)
                        .lineLimit(1...5)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: notiz) { _, t in kern.notizSetzen(brief.id, t) }
                }
                if kern.mehrereKonten && !brief.kontoName.isEmpty {
                    LabeledContent(T("Postfach"), value: brief.kontoName).font(.callout)
                }
            }
            .padding()
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(brief.titel)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem {
                ShareLink(item: T("Brief von %1, angekündigt %2", brief.titel, Texte.tag(brief.datum))) {
                    Label(T("Teilen"), systemImage: "square.and.arrow.up")
                }
            }
        }
        .task(id: brief.id) { notiz = kern.notiz(brief.id) }
    }

    private func erinnern(_ tage: Int) {
        let n = kern.notiz(brief.id)
        Task { await kern.erinnern(titel: T("Brief von %1", brief.titel), notiz: n.isEmpty ? T("Angekündigt %1", Texte.tag(brief.datum)) : n, in: tage) }
    }
}
