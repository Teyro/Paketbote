import AppKit
import Carbon.HIToolbox
import PaketKern

/// Liste der Sendungen drucken (oder als PDF sichern – über den Druckdialog)
@MainActor
enum Drucken {
    static func liste(_ kern: Kern) {
        let g = kern.gruppen
        let text = NSMutableAttributedString()
        let titel: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 18)]
        let kopf: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 13)]
        let normal: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11)]
        let klein: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.darkGray]
        text.append(NSAttributedString(string: T("Paketbote") + " – " + Date().formatted(date: .long, time: .shortened) + "\n\n", attributes: titel))
        for (name, liste) in [(T("Heute"), g.heute), (T("Unterwegs"), g.unterwegs), (T("Zugestellt"), g.zugestellt)] where !liste.isEmpty {
            text.append(NSAttributedString(string: name + "\n", attributes: kopf))
            for s in liste {
                text.append(NSAttributedString(string: "\(s.titel) · \(s.dienstName)\(s.nummer.isEmpty ? "" : " · " + s.nummer)\n", attributes: normal))
                text.append(NSAttributedString(string: "   " + Texte.zeile(s) + "\n", attributes: klein))
                for e in s.ereignisse.prefix(6) {
                    text.append(NSAttributedString(string: "   \(Texte.ereigniszeit(e.zeit))  \(e.text)\(e.ort.isEmpty ? "" : " – " + e.ort)\n", attributes: klein))
                }
            }
            text.append(NSAttributedString(string: "\n"))
        }
        let ansicht = NSTextView(frame: NSRect(x: 0, y: 0, width: 520, height: 700))
        ansicht.textStorage?.setAttributedString(text)
        let info = NSPrintInfo.shared
        info.topMargin = 40; info.bottomMargin = 40; info.leftMargin = 40; info.rightMargin = 40
        info.isVerticallyCentered = false
        NSPrintOperation(view: ansicht, printInfo: info).run()
    }
}

/// Tastenkürzel von überall: ⌥⌘P öffnet „Sendung hinzufügen“ (mit der Nummer aus der Zwischenablage, falls eine drin ist)
enum Tastenkuerzel {
    nonisolated(unsafe) static var ref: EventHotKeyRef?

    static func anmelden() {
        var typ = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    let kern = Kern.shared
                    kern.hinzufuegenNummer = NSPasteboard.general.string(forType: .string).flatMap(Dienst.nummerIn) ?? ""
                    kern.hinzufuegenOffen = true
                    NSApp.activate(ignoringOtherApps: true)
                    for w in NSApp.windows where w.canBecomeMain { w.makeKeyAndOrderFront(nil) }
                }
            }
            return noErr
        }, 1, &typ, nil, nil)
        let id = EventHotKeyID(signature: OSType(0x50424f54), id: 1)  // "PBOT"
        RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(optionKey | cmdKey), id, GetApplicationEventTarget(), 0, &ref)
    }
}
