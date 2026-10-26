import SwiftUI
import PaketKern

/// Sendung von Hand verfolgen: Nummer (auch aus der Zwischenablage), Dienst (meist erkannt), Name
struct HinzufuegenAnsicht: View {
    let kern: Kern
    var vorgabe = ""
    @Environment(\.dismiss) private var schliessen
    @State private var nummer = ""
    @State private var dienst = ""
    @State private var name = ""
    @State private var laeuft = false
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
                        if let n = Zwischenablage.text.flatMap(Dienst.nummerIn), n != nummer {
                            Button { nummer = n } label: { Label(T("Einfügen"), systemImage: "doc.on.clipboard") }
                                .labelStyle(.iconOnly)
                                .help(T("Nummer aus der Zwischenablage"))
                        }
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
                    }
                }
                Section {
                    TextField(T("Name, z. B. „Neue Schuhe“ (optional)"), text: $name).onSubmit(senden)
                } footer: {
                    Text(T("Home Assistant verfolgt die Sendung ab jetzt mit – Mails zur selben Nummer ergänzen sie."))
                }
            }
            .formStyle(.grouped)
            .navigationTitle(T("Sendung hinzufügen"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Abbrechen")) { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    if laeuft { ProgressView() } else { Button(T("Hinzufügen"), action: senden).disabled(!bereit) }
                }
            }
            .onAppear {
                if nummer.isEmpty { nummer = vorgabe }
                fokus = true
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 300)
        #endif
    }

    private func senden() {
        guard bereit else { return }
        laeuft = true
        Task {
            let ok = await kern.hinzufuegen(nummer: nummer.trimmingCharacters(in: .whitespaces), dienst: gewaehlt,
                                            name: name.trimmingCharacters(in: .whitespaces))
            laeuft = false
            if ok { schliessen() }
        }
    }
}
