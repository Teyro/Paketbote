import Foundation
import AppKit
import Observation
import PaketKern

/// Updates für den Mac: neueste Version auf GitHub suchen, ZIP laden, prüfen, App austauschen, neu starten.
@MainActor
@Observable
final class Aktualisierer {
    static let shared = Aktualisierer()
    static let projekt = "https://github.com/Teyro/Paketbote/releases/download/"

    let aktuelleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    private(set) var neueVersion: String?
    private(set) var downloadURL: URL?
    private(set) var fehler = ""

    func pruefen() async {
        guard let url = URL(string: "https://api.github.com/repos/Teyro/Paketbote/releases/latest") else { return }
        var r = URLRequest(url: url)
        r.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (d, a) = try? await URLSession.shared.data(for: r), (a as? HTTPURLResponse)?.statusCode == 200, let j = JSON.lesen(d),
              let tag = j["tag_name"]?.text else { return }
        let v = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        guard v.compare(aktuelleVersion, options: .numeric) == .orderedDescending else { neueVersion = nil; return }
        // nur Downloads aus diesem Projekt
        downloadURL = (j["assets"]?.liste ?? []).compactMap { a -> URL? in
            guard let n = a["name"]?.text, n.hasPrefix("Paketbote-macOS-"), n.hasSuffix(".zip"),
                  let s = a["browser_download_url"]?.text, s.hasPrefix(Self.projekt), !s.contains("..") else { return nil }
            return URL(string: s)
        }.first
        neueVersion = downloadURL == nil ? nil : v
    }

    func installieren() async {
        guard let url = downloadURL else { return }
        do {
            let (datei, antwort) = try await URLSession.shared.download(from: url)
            guard (antwort as? HTTPURLResponse)?.statusCode == 200 else { throw Fehler(T("Download fehlgeschlagen")) }
            let ordner = FileManager.default.temporaryDirectory.appendingPathComponent("Paketbote-Update-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
            let zip = ordner.appendingPathComponent("update.zip")
            try FileManager.default.moveItem(at: datei, to: zip)
            try ausfuehren("/usr/bin/ditto", ["-x", "-k", zip.path, ordner.path])
            let neu = ordner.appendingPathComponent("Paketbote.app")
            guard Bundle(url: neu)?.bundleIdentifier == "de.teyro.paketbote" else { throw Fehler(T("Die geladene Datei ist nicht Paketbote.")) }
            try ausfuehren("/usr/bin/codesign", ["--verify", "--deep", "--strict", neu.path])
            try? ausfuehren("/usr/bin/xattr", ["-dr", "com.apple.quarantine", neu.path])
            austauschenUndNeuStarten(neu)
        } catch {
            fehler = (error as? Fehler)?.text ?? error.localizedDescription
            Kern.shared.meldung = fehler
        }
    }

    /// Kleines Skript: wartet, bis die App beendet ist, tauscht sie aus und startet die neue
    private func austauschenUndNeuStarten(_ neu: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", """
        while kill -0 \(pid) 2>/dev/null; do sleep 0.3; done
        rm -rf "$ZIEL.alt"
        mv "$ZIEL" "$ZIEL.alt" && mv "$NEU" "$ZIEL" && rm -rf "$ZIEL.alt" || mv "$ZIEL.alt" "$ZIEL"
        open "$ZIEL"
        """]
        p.environment = ["ZIEL": Bundle.main.bundleURL.path, "NEU": neu.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
        if (try? p.run()) != nil {
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                NSApp.terminate(nil)
            }
        }
    }

    private struct Fehler: Error { let text: String; init(_ t: String) { text = t } }

    private func ausfuehren(_ programm: String, _ argumente: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: programm)
        p.arguments = argumente
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 { throw Fehler(T("%1 meldet Fehler %2.", URL(fileURLWithPath: programm).lastPathComponent, "\(p.terminationStatus)")) }
    }
}
