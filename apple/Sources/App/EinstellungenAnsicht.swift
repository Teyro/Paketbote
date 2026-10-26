import SwiftUI
import PaketKern

/// Einstellungen: Home Assistant, Postfach, Mitteilungen, Hinweise zur Integration
struct EinstellungenAnsicht: View {
    @Bindable var kern: Kern
    @Environment(\.dismiss) private var schliessen
    @State private var pruefung = ""
    @State private var prueft = false

    var body: some View {
        @Bindable var e = kern.einstellungen
        Form {
            Section {
                TextField(T("Adresse, z. B. http://homeassistant.local:8123"), text: $e.adresse)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                SecureField(T("Langlebiges Zugriffstoken"), text: $e.token)
                HStack {
                    Button(T("Verbindung prüfen")) { pruefen() }.disabled(!e.eingerichtet || prueft)
                    if prueft { ProgressView().controlSize(.small) }
                }
                if !pruefung.isEmpty { Text(pruefung).font(.callout).foregroundStyle(.secondary) }
            } header: {
                Text(T("Home Assistant"))
            } footer: {
                Text(T("Das Token legst du in Home Assistant an: unten links auf deinen Namen → Sicherheit → Langlebige Zugriffstoken."))
            }

            if let konten = kern.daten?.konten, konten.count > 1 {
                Section(T("Postfach")) {
                    Picker(T("Zeigen"), selection: $e.konto) {
                        Text(T("Alle")).tag("")
                        ForEach(konten) { Text($0.name).tag($0.name) }
                    }
                }
            }

            Section {
                Toggle(T("Mitteilungen bei neuem Stand"), isOn: $e.mitteilungen)
                    .onChange(of: e.mitteilungen) { _, an in if an { Task { await kern.mitteilungenErlauben() } } }
                Stepper(T("Zugestellte %1 Tage zeigen", "\(e.tageZugestellt)"), value: $e.tageZugestellt, in: 1...60)
            } header: {
                Text(T("Anzeige"))
            } footer: {
                Text(T("Die App meldet sich, wenn sie neu lädt. Zuverlässiger im Hintergrund: in der Integration „Mitteilungen an“ die Home-Assistant-App wählen."))
            }

            if let k = kern.daten?.konten.first {
                Section(T("Sendungsverfolgung")) {
                    LabeledContent(T("DHL live"), value: k.dhlLive ? T("an") : T("aus – DHL-Schlüssel in der Integration"))
                    LabeledContent(T("17TRACK"), value: k.siebzehn ? (k.siebzehnRest.map { T("an – noch %1 Sendungen frei", "\($0)") } ?? T("an")) : T("aus – Schlüssel in der Integration"))
                }
            }

            Section(T("Über")) {
                LabeledContent(T("Version"), value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                Link(T("Paketbote auf GitHub"), destination: URL(string: "https://github.com/Teyro/Paketbote")!)
                Link(T("Integration „Briefankündigung“ (HACS)"), destination: URL(string: "https://github.com/Teyro/Briefankuendigung-HA")!)
                if !Ablage.gruppeDa {
                    Text(T("Hinweis: Die App-Gruppe fehlt (Signatur) – die Widgets können dann keine Sendungen zeigen."))
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(T("Einstellungen"))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(T("Fertig")) {
                    schliessen()
                    Task { await kern.laden() }
                }
            }
        }
    }

    private func pruefen() {
        prueft = true
        pruefung = ""
        let ha = kern.ha
        Task {
            do {
                let u = try await ha.laden()
                let offen = u.sendungen.filter { !$0.fertig }.count
                pruefung = T("Verbunden – %1 Postfächer, %2 unterwegs.", "\(u.konten.count)", Texte.anzahl(offen))
                if u.version < 4 { pruefung += " " + T("Für Verlauf und Umbenennen die Integration auf 1.5 aktualisieren.") }
            } catch let f as HAFehler {
                pruefung = f.text
            } catch {
                pruefung = error.localizedDescription
            }
            prueft = false
        }
    }
}
