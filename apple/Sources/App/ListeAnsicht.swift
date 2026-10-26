import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
import PaketKern

/// Hauptansicht: Liste links (bzw. oben), Sendung rechts (bzw. beim Antippen)
struct Hauptansicht: View {
    @Bindable var kern: Kern

    var body: some View {
        NavigationSplitView {
            SendungsListe(kern: kern)
                .navigationTitle(T("Pakete"))
                #if os(macOS)
                .navigationSplitViewColumnWidth(min: 300, ideal: 340)
                #endif
        } detail: {
            if let s = kern.sendung(kern.auswahl) {
                DetailAnsicht(kern: kern, sendung: s)
            } else {
                ContentUnavailableView(T("Keine Sendung gewählt"), systemImage: "shippingbox", description: Text(T("Links eine Sendung wählen.")))
            }
        }
        .sheet(isPresented: $kern.hinzufuegenOffen) {
            HinzufuegenAnsicht(kern: kern)
        }
        .sheet(isPresented: $kern.statistikOffen) {
            NavigationStack { StatistikAnsicht(kern: kern) }
                #if os(macOS)
                .frame(minWidth: 560, minHeight: 600)
                #endif
        }
        .sheet(isPresented: $kern.einstellungenOffen) {
            NavigationStack { EinstellungenAnsicht(kern: kern) }
                #if os(macOS)
                .frame(minWidth: 480, minHeight: 520)
                #endif
        }
        .overlay(alignment: .bottom) { MeldungsBand(kern: kern) }
        .task {
            await kern.laden()
            if !kern.bereit && !kern.vorschau { kern.einstellungenOffen = true }
        }
    }
}

/// Kurze Meldung unten (verschwindet nach ein paar Sekunden)
struct MeldungsBand: View {
    let kern: Kern
    var body: some View {
        if !kern.meldung.isEmpty {
            Text(kern.meldung)
                .font(.callout.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .shadow(radius: 6, y: 2)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: kern.meldung) {
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation { kern.meldung = "" }
                }
        }
    }
}

struct SendungsListe: View {
    @Bindable var kern: Kern
    @State private var zugestelltOffen = true
    @State private var umbenennen: Sendung?
    @State private var neuerName = ""

    var body: some View {
        let g = kern.gruppen
        List(selection: $kern.auswahl) {
            if !kern.bereit {
                Section {
                    EinrichtenHinweis(kern: kern)
                }
            } else if !kern.fehler.isEmpty {
                Section {
                    Label(kern.fehler, systemImage: "wifi.exclamationmark").foregroundStyle(.red)
                }
            }
            if !g.heute.isEmpty {
                Section(T("Heute")) { ForEach(g.heute) { zeile($0) } }
            }
            if !g.unterwegs.isEmpty {
                Section(T("Unterwegs")) { ForEach(g.unterwegs) { zeile($0) } }
            }
            if !g.zugestellt.isEmpty {
                Section(isExpanded: $zugestelltOffen) {
                    ForEach(g.zugestellt) { zeile($0) }
                } header: {
                    Text(T("Zugestellt"))
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.sidebar)
        #endif
        .overlay {
            if kern.bereit && (kern.daten != nil || !kern.einstellungen.eingerichtet) && g.aktiv.isEmpty && g.zugestellt.isEmpty {
                ContentUnavailableView {
                    Label(T("Keine Pakete unterwegs"), systemImage: "shippingbox")
                } description: {
                    Text(kern.einstellungen.eingerichtet ? T("Versandmails von DHL, Hermes, DPD, GLS, UPS und Amazon erscheinen hier – oder eine Sendung mit ＋ hinzufügen.")
                         : T("Sendungsnummer mit ＋ eintragen oder den Paketschein scannen – Paketbote holt Stand, Verlauf und Karte."))
                } actions: {
                    Button(T("Sendung hinzufügen")) { kern.hinzufuegenOffen = true }.buttonStyle(.borderedProminent)
                }
            } else if kern.daten == nil && kern.laedt {
                ProgressView()
            }
        }
        .refreshable { await kern.laden() }
        .dropDestination(for: String.self) { texte, _ in
            guard let n = texte.lazy.compactMap({ Dienst.nummerIn($0) }).first else { return false }
            kern.hinzufuegenNummer = n
            kern.hinzufuegenOffen = true
            return true
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { kern.hinzufuegenOffen = true } label: { Label(T("Sendung hinzufügen"), systemImage: "plus") }
                    .keyboardShortcut("n")
            }
            ToolbarItem {
                Menu {
                    if kern.einstellungen.eingerichtet {
                        Button { Task { await kern.jetztNachsehen() } } label: { Label(T("Postfach jetzt lesen"), systemImage: "envelope.arrow.triangle.branch") }
                    }
                    Button { Task { await kern.laden() } } label: { Label(T("Neu laden"), systemImage: "arrow.clockwise") }
                    Divider()
                    Button { kern.statistikOffen = true } label: { Label(T("Statistik"), systemImage: "chart.bar.xaxis") }
                    #if os(macOS)
                    Button { Drucken.liste(kern) } label: { Label(T("Drucken …"), systemImage: "printer") }
                    #endif
                    Button { kern.einstellungenOffen = true } label: { Label(T("Einstellungen …"), systemImage: "gearshape") }
                } label: {
                    Label(T("Mehr"), systemImage: "ellipsis.circle")
                }
            }
        }
        .alert(T("Umbenennen"), isPresented: Binding(get: { umbenennen != nil }, set: { if !$0 { umbenennen = nil } })) {
            TextField(T("Name"), text: $neuerName)
            Button(T("Sichern")) { if let s = umbenennen { Task { await kern.umbenennen(s, neuerName) } } }
            Button(T("Abbrechen"), role: .cancel) {}
        } message: {
            Text(T("Leer lassen, um wieder den Absender zu zeigen."))
        }
    }

    private func zeile(_ s: Sendung) -> some View {
        SendungsZeile(sendung: s, mitKonto: kern.mehrereKonten)
            .tag(s.id)
            .contextMenu { aktionen(s) }
            .swipeActions(edge: .trailing) {
                if s.manuell {
                    Button(role: .destructive) { Task { await kern.entfernen(s) } } label: { Label(T("Entfernen"), systemImage: "trash") }
                }
                if !s.fertig {
                    Button { Task { await kern.erledigt(s, true) } } label: { Label(T("Angekommen"), systemImage: "checkmark") }.tint(.green)
                }
            }
            .swipeActions(edge: .leading) {
                Button { neuerName = s.name; umbenennen = s } label: { Label(T("Umbenennen"), systemImage: "pencil") }.tint(.indigo)
            }
    }

    @ViewBuilder
    private func aktionen(_ s: Sendung) -> some View {
        if let u = s.verfolgenURL { Link(destination: u) { Label(T("Beim Dienst verfolgen"), systemImage: "safari") } }
        Button { neuerName = s.name; umbenennen = s } label: { Label(T("Umbenennen"), systemImage: "pencil") }
        if !s.nummer.isEmpty {
            Button { Zwischenablage.kopieren(s.nummer) } label: { Label(T("Nummer kopieren"), systemImage: "doc.on.doc") }
        }
        if s.erledigt {
            Button { Task { await kern.erledigt(s, false) } } label: { Label(T("Doch nicht angekommen"), systemImage: "arrow.uturn.backward") }
        } else if !s.fertig {
            Button { Task { await kern.erledigt(s, true) } } label: { Label(T("Angekommen"), systemImage: "checkmark") }
        }
        if s.manuell {
            Button(role: .destructive) { Task { await kern.entfernen(s) } } label: { Label(T("Entfernen"), systemImage: "trash") }
        }
    }
}

/// Eine Zeile: Logo, Name, Stand, Fortschritt
struct SendungsZeile: View {
    let sendung: Sendung
    var mitKonto = false

    var body: some View {
        HStack(spacing: 12) {
            DienstLogo(dienst: sendung.dienst, groesse: 44)
                .opacity(sendung.fertig ? 0.6 : 1)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    if sendung.ruecksendung { Etikett(text: T("Rücksendung"), farbe: .purple) }
                    Text(sendung.titel)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                }
                Text(Texte.zeile(sendung, mitKonto: mitKonto))
                    .font(.subheadline)
                    .foregroundStyle(standFarbe(sendung))
                    .lineLimit(1)
                if !sendung.fertig { Fortschritt(sendung: sendung, hoehe: 4).frame(maxWidth: 180) }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct EinrichtenHinweis: View {
    let kern: Kern
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(T("Willkommen bei Paketbote"), systemImage: "shippingbox.fill").font(.headline)
            Text(T("Einfach eine Sendungsnummer eintragen – oder mit Home Assistant verbinden: dann kommen auch die Pakete aus deinen Versandmails dazu."))
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Button(T("Sendung hinzufügen")) { kern.einstellungen.direktModus = true; kern.hinzufuegenOffen = true }.buttonStyle(.borderedProminent)
                Button(T("Home Assistant …")) { kern.einstellungenOffen = true }.buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 6)
    }
}

/// Zwischenablage für beide Systeme
enum Zwischenablage {
    static func kopieren(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    static var text: String? {
        #if os(iOS)
        UIPasteboard.general.string
        #else
        NSPasteboard.general.string(forType: .string)
        #endif
    }
}
