import Foundation
import WatchConnectivity
import PaketKern

/// Verbindung zur Apple Watch: schickt Zugang und Stand (die Uhr lädt dann selbst aus Home Assistant)
@MainActor
final class Uhr: NSObject, WCSessionDelegate {
    static let shared = Uhr()

    func starten() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func senden(_ kern: Kern) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated, WCSession.default.isWatchAppInstalled else { return }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        var u = kern.daten ?? Uebersicht()
        u.sendungen = kern.alle
        let stand = (try? enc.encode(u)) ?? Data()
        try? WCSession.default.updateApplicationContext([
            "adresse": kern.einstellungen.adresse, "token": kern.einstellungen.token, "konto": kern.einstellungen.konto, "stand": stand,
        ])
    }

    nonisolated func session(_ s: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.senden(Kern.shared) }
    }
    nonisolated func sessionDidBecomeInactive(_ s: WCSession) {}
    nonisolated func sessionDidDeactivate(_ s: WCSession) { WCSession.default.activate() }
}
