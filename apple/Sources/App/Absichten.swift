import AppIntents
import PaketKern

// Siri und Kurzbefehle: „Welche Pakete kommen heute?“, „Sendung hinzufügen“

struct PaketeHeuteAbsicht: AppIntent {
    static let title: LocalizedStringResource = "Welche Pakete kommen heute?"
    static let description = IntentDescription("Sagt, welche Pakete heute kommen oder zur Abholung bereitliegen.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let u = try await Kern.shared.ha.laden()
        Ablage.schreiben(u)
        let satz = Texte.heuteSatz(Gruppen(u.sendungen))
        return .result(value: satz, dialog: IntentDialog(stringLiteral: satz))
    }
}

struct SendungHinzufuegenAbsicht: AppIntent {
    static let title: LocalizedStringResource = "Sendung hinzufügen"
    static let description = IntentDescription("Verfolgt eine Sendung über Home Assistant (Paketdienst wird an der Nummer erkannt).")

    @Parameter(title: "Sendungsnummer") var nummer: String
    @Parameter(title: "Name") var name: String?

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$nummer) als \(\.$name) verfolgen")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let n = Dienst.nummerIn(nummer) ?? nummer.trimmingCharacters(in: .whitespaces)
        do {
            try await Kern.shared.ha.hinzufuegen(nummer: n, dienst: Dienst.vonNummer(n), name: name ?? "")
        } catch let f as HAFehler {
            if f.status == 400 { throw $nummer.needsValueError(IntentDialog(stringLiteral: T("Die Nummer kenne ich nicht – bitte in der App mit Paketdienst hinzufügen."))) }
            throw f
        }
        await Kern.shared.laden(still: true)
        return .result(dialog: IntentDialog(stringLiteral: T("Ich verfolge jetzt %1.", name?.isEmpty == false ? name! : n)))
    }
}

extension HAFehler: CustomLocalizedStringResourceConvertible {
    public var localizedStringResource: LocalizedStringResource { LocalizedStringResource(stringLiteral: text) }
}

struct PaketboteKurzbefehle: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: PaketeHeuteAbsicht(), phrases: [
            "Welche Pakete kommen heute mit \(.applicationName)?",
            "Kommt heute ein Paket mit \(.applicationName)?",
            "\(.applicationName) heute",
        ], shortTitle: "Pakete heute", systemImageName: "shippingbox")
        AppShortcut(intent: SendungHinzufuegenAbsicht(), phrases: [
            "Sendung mit \(.applicationName) verfolgen",
            "Paket zu \(.applicationName) hinzufügen",
        ], shortTitle: "Sendung hinzufügen", systemImageName: "plus")
    }
}
