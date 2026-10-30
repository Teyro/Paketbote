import SwiftUI
import PaketKern

/// Sendung verfolgen: Nummer (eintippen, einfügen, scannen), Dienst (meist erkannt), Name, Rücksendung
struct HinzufuegenAnsicht: View {
    let kern: Kern
    @Environment(\.dismiss) private var schliessen
    @State private var nummer = ""
    @State private var dienst = ""
    @State private var name = ""
    @State private var ruecksendung = false
    @State private var laeuft = false
    @State private var scannen = false
    @FocusState private var fokus: Bool

    private var erkannt: String { Dienst.vonNummer(nummer) }
    private var gewaehlt: String { dienst.isEmpty ? erkannt : dienst }
    private var bereit: Bool { !nummer.trimmingCharacters(in: .whitespaces).isEmpty && !gewaehlt.isEmpty && !laeuft }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField(T("Sendungs- oder Bestellnummer"), text: $nummer)
                            .focused($fokus)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.characters)
                            #endif
                            .onSubmit(senden)
                        // Einfügen ohne Nachfrage des Systems
                        PasteButton(payloadType: String.self) { texte in
                            if let n = texte.lazy.compactMap({ Dienst.nummerIn($0) }).first { nummer = n }
                        }
                        .labelStyle(.iconOnly)
                        .buttonBorderShape(.capsule)
                        #if os(iOS)
                        if Scanner.moeglich {
                            Button { scannen = true } label: { Label(T("Paketschein scannen"), systemImage: "barcode.viewfinder") }
                                .labelStyle(.iconOnly)
                        }
                        #endif
                    }
                    Picker(T("Paketdienst"), selection: $dienst) {
                        Text(erkannt.isEmpty ? T("Bitte wählen") : T("Automatisch (%1)", Dienst.name(erkannt))).tag("")
                        ForEach(Dienst.alle, id: \.self) { d in
                            Label { Text(Dienst.name(d)) } icon: { DienstLogo(dienst: d, groesse: 20) }.tag(d)
                        }
                    }
                } footer: {
                    if !nummer.isEmpty && gewaehlt.isEmpty {
                        Text(T("Die Nummer passt zu mehreren Diensten – bitte den Paketdienst wählen."))
                    } else if !gewaehlt.isEmpty {
                        let quellen = kern.verfolgung.moeglich(gewaehlt)
                        Text(quellen.isEmpty ? T("Für %1 ist noch kein Anbieter eingerichtet (Einstellungen → Direkt verfolgen).", Dienst.name(gewaehlt))
                             : T("Abfrage über %1.", quellen.joined(separator: " → ")))
                    }
                }
                Section {
                    TextField(T("Name, z. B. „Neue Schuhe“ (optional)"), text: $name).onSubmit(senden)
                    Toggle(T("Rücksendung"), isOn: $ruecksendung)
                } footer: {
                    Text(kern.einstellungen.eingerichtet && kern.einstellungen.auchInHA
                         ? T("Post & Pakete fragt selbst bei den Anbietern nach und trägt die Sendung auch in Home Assistant ein.")
                         : T("Post & Pakete fragt selbst bei den Anbietern nach – auch ohne Home Assistant."))
                }
            }
            .formStyle(.grouped)
            .navigationTitle(T("Sendung hinzufügen"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $scannen) { ScannerBlatt { nummer = $0 } }
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Abbrechen")) { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    if laeuft { ProgressView() } else { Button(T("Hinzufügen"), action: senden).disabled(!bereit) }
                }
            }
            .onAppear {
                if nummer.isEmpty { nummer = kern.hinzufuegenNummer }
                kern.hinzufuegenNummer = ""
                fokus = nummer.isEmpty
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 360)
        #endif
    }

    private func senden() {
        guard bereit else { return }
        laeuft = true
        Task {
            let ok = await kern.hinzufuegen(nummer: nummer.trimmingCharacters(in: .whitespaces), dienst: gewaehlt,
                                            name: name.trimmingCharacters(in: .whitespaces), ruecksendung: ruecksendung)
            laeuft = false
            if ok {
                schliessen()
                if let s = kern.sendung(kern.auswahl) { await kern.jetztAbfragen(s) }
            }
        }
    }
}
