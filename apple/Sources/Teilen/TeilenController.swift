import UIKit
import UniformTypeIdentifiers

/// „Teilen“ → Paketbote: sucht in Text oder Link eine Sendungsnummer und öffnet die App mit „Sendung hinzufügen“.
/// (Ohne App-Gruppe kann die Erweiterung nichts speichern – sie übergibt die Nummer per paketbote://neu?nummer=…)
final class TeilenController: UIViewController {
    private let hinweis = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        hinweis.translatesAutoresizingMaskIntoConstraints = false
        hinweis.numberOfLines = 0
        hinweis.textAlignment = .center
        hinweis.font = .preferredFont(forTextStyle: .headline)
        view.addSubview(hinweis)
        NSLayoutConstraint.activate([
            hinweis.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hinweis.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            hinweis.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40),
        ])
        Task { await auswerten() }
    }

    private func auswerten() async {
        var texte: [String] = []
        for item in extensionContext?.inputItems as? [NSExtensionItem] ?? [] {
            if let t = item.attributedContentText?.string { texte.append(t) }
            for a in item.attachments ?? [] {
                for typ in [UTType.plainText, .url] where a.hasItemConformingToTypeIdentifier(typ.identifier) {
                    if let wert = try? await a.loadItem(forTypeIdentifier: typ.identifier) {
                        if let s = wert as? String { texte.append(s) }
                        if let u = wert as? URL { texte.append(u.absoluteString) }
                    }
                }
            }
        }
        let nummer = texte.lazy.compactMap(Self.nummerIn).first
        guard let nummer, let url = URL(string: "paketbote://neu?nummer=" + (nummer.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? nummer)) else {
            hinweis.text = NSLocalizedString("Keine Sendungsnummer gefunden.", comment: "")
            try? await Task.sleep(for: .seconds(1.6))
            extensionContext?.completeRequest(returningItems: nil)
            return
        }
        hinweis.text = "📦 " + nummer
        oeffnen(url)
        try? await Task.sleep(for: .milliseconds(400))
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// Erweiterungen dürfen keine App öffnen – außer über die Kette der Responder bis zur Anwendung
    /// (dynamisch aufgerufen, weil UIApplication.open in Erweiterungen gesperrt ist)
    private func oeffnen(_ url: URL) {
        let sel = NSSelectorFromString("openURL:options:completionHandler:")
        typealias Oeffnen = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, AnyObject?) -> Void
        var r: UIResponder? = self
        while let x = r {
            if x.responds(to: sel), let imp = x.method(for: sel) {
                unsafeBitCast(imp, to: Oeffnen.self)(x, sel, url as NSURL, NSDictionary(), nil)
                return
            }
            r = x.next
        }
    }

    /// Gleiches Muster wie Dienst.nummerIn (die Erweiterung bindet den Kern nicht ein, damit sie klein bleibt)
    static func nummerIn(_ text: String) -> String? {
        let muster = "TBA[0-9]{9,14}|[0-9]{3}-[0-9]{7}-[0-9]{7}|JJD[0-9]{12,20}|1Z[0-9A-Z]{16}|H[0-9A-Z]{19}|[0-9]{11,20}"
        guard let r = text.uppercased().range(of: muster, options: .regularExpression) else { return nil }
        return String(text.uppercased()[r])
    }
}
