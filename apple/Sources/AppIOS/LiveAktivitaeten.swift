import ActivityKit
import Foundation
import PaketKern

/// Live-Aktivitäten: je Paket, das heute kommt (bzw. zur Abholung bereitliegt), eine Anzeige auf dem Sperrbildschirm
/// und in der Dynamic Island. Starten geht nur, wenn die App offen ist; aktualisiert wird auch im Hintergrundabruf.
@MainActor
enum LiveAktivitaeten {
    static func abgleichen(_ kern: Kern, darfStarten: Bool) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let heute = kern.einstellungen.liveAktivitaet ? kern.gruppen.heute : []
        let laufend = Activity<PaketAktivitaet>.activities
        for a in laufend {
            if let s = heute.first(where: { $0.id == a.attributes.id }) {
                await a.update(ActivityContent(state: zustand(s), staleDate: Date().addingTimeInterval(4 * 3600)))
            } else {
                // zugestellt oder nicht mehr heute: mit dem letzten Stand beenden
                let s = kern.sendung(a.attributes.id)
                let ende = s.map(zustand) ?? a.content.state
                await a.end(ActivityContent(state: ende, staleDate: nil), dismissalPolicy: s?.fertig == true ? .after(Date().addingTimeInterval(1800)) : .immediate)
            }
        }
        guard darfStarten else { return }
        for s in heute.prefix(3) where !laufend.contains(where: { $0.attributes.id == s.id }) {
            let a = PaketAktivitaet(id: s.id, titel: s.titel, dienst: s.dienst)
            _ = try? Activity.request(attributes: a, content: ActivityContent(state: zustand(s), staleDate: Date().addingTimeInterval(4 * 3600)))
        }
    }

    static func zustand(_ s: Sendung) -> PaketAktivitaet.ContentState {
        .init(stand: s.stand, standText: s.zumAbholen && !s.abholort.isEmpty ? s.abholort : Texte.stand(s), stufe: s.stufe,
              zeitfenster: s.zeitfenster, abholcode: s.zumAbholen ? s.abholcode : "")
    }
}
