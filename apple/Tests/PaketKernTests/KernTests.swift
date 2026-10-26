import XCTest
@testable import PaketKern

final class KernTests: XCTestCase {
    let kal: Calendar = {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return k
    }()
    lazy var jetzt = kal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 9))!

    func beispiel() -> Uebersicht {
        let ms = { (d: Date) -> JSON in .zahl(d.timeIntervalSince1970 * 1000) }
        let j: JSON = ["version": 4, "stand": ms(jetzt), "konten": [["id": "e1", "name": "Kim", "siebzehn": true, "siebzehn_rest": 198]],
                       "briefe": [
            ["id": "p1", "datum": ms(jetzt), "art": "paket", "absender": "OTTO", "sendung": "H1002345678901234567", "dienst": "hermes",
             "erwartet": "2026-10-23", "zeitfenster": "10:00–13:00", "verfolgen": "https://www.myhermes.de/x", "konto": "e1", "konto_name": "Kim",
             "ereignisse": [["zeit": "2026-10-20T18:00:00+02:00", "text": "Im Verteilzentrum", "ort": "Ketzin"]]],
            ["id": "p2", "datum": ms(jetzt), "art": "paket", "absender": "Zalando", "dienst": "dpd", "stand": "heute", "konto": "e1"],
            ["id": "p3", "datum": ms(jetzt), "art": "paket", "absender": "Kindle", "name": "Geschenk Oma", "dienst": "amazon", "erwartet": "2026-10-22",
             "kundenkonto": "Johanna", "manuell": true, "konto": "e1"],
            ["id": "p4", "datum": ms(jetzt), "art": "paket", "absender": "Alt", "stand": "zugestellt", "konto": "e1"],
            ["id": "p5", "datum": ms(jetzt), "art": "paket", "absender": "Kaffee", "stand": "abholbereit", "dienst": "gls", "konto": "e1"],
            ["id": "b1", "datum": ms(jetzt), "art": "brief", "absender": "AOK"],
        ]]
        return Uebersicht.aus(j)!
    }

    func testLesenUndGruppen() {
        let u = beispiel()
        XCTAssertEqual(u.sendungen.count, 5, "Briefe zählen nicht")
        XCTAssertEqual(u.konten.first?.siebzehnRest, 198)
        let g = Gruppen(u.sendungen, jetzt: jetzt, kalender: kal)
        XCTAssertEqual(g.heute.map(\.id), ["p2", "p5"], "abholbereit hinten")
        XCTAssertEqual(g.unterwegs.map(\.id), ["p3", "p1"], "nach Termin")
        XCTAssertEqual(g.zugestellt.map(\.id), ["p4"])
        let otto = u.sendungen[0]
        XCTAssertEqual(otto.ereignisse.first?.ort, "Ketzin")
        XCTAssertNotNil(otto.ereignisse.first?.zeit)
        XCTAssertEqual(otto.stufe, 2)
        XCTAssertEqual(u.sendungen[2].titel, "Geschenk Oma")
        XCTAssertEqual(u.sendungen[4].dienstName, "GLS")
    }

    func testTexte() {
        let u = beispiel()
        XCTAssertEqual(Texte.stand(u.sendungen[0], jetzt: jetzt, kalender: kal), "voraussichtlich Fr 23.10., 10:00–13:00")
        XCTAssertEqual(Texte.zeile(u.sendungen[2], jetzt: jetzt, kalender: kal), "kommt morgen · Johanna")
        XCTAssertEqual(Texte.stand(u.sendungen[4], jetzt: jetzt, kalender: kal), "zur Abholung bereit")
        XCTAssertEqual(Texte.titel(Gruppen(u.sendungen, jetzt: jetzt, kalender: kal).aktiv), "4 Pakete unterwegs")
        let satz = Texte.heuteSatz(Gruppen(u.sendungen, jetzt: jetzt, kalender: kal))
        XCTAssertEqual(satz, "Heute kommt ein Paket: Zalando (DPD). Zur Abholung bereit: Kaffee (GLS).")
        var spaet = u.sendungen[0]
        spaet.erwartet = "2026-10-19"
        XCTAssertEqual(Texte.stand(spaet, jetzt: jetzt, kalender: kal), "überfällig seit 19.10.")
    }

    func testDiensteUndMitteilungen() {
        XCTAssertEqual(Dienst.vonNummer("1Z999AA10123456784"), "ups")
        XCTAssertEqual(Dienst.vonNummer("TBA301234567890"), "amazon")
        XCTAssertEqual(Dienst.vonNummer("01234567890123"), "")
        XCTAssertEqual(Dienst.nummerIn("Ihre Sendungsnummer: 00340434161094015902 – danke"), "00340434161094015902")
        XCTAssertEqual(Dienst.verfolgen("gls", "123")?.host, "gls-group.com")
        let u = beispiel()
        var neu = u.sendungen[0]
        neu.stand = "heute"
        XCTAssertEqual(Texte.mitteilung(alt: u.sendungen[0], neu: neu)?.titel, "📦 Kommt heute")
        XCTAssertNil(Texte.mitteilung(alt: neu, neu: neu))
        XCTAssertEqual(u.nur(konto: "e1").sendungen.count, 5)
        XCTAssertEqual(u.nur(konto: "johanna").sendungen.count, 0)
        XCTAssertEqual(Texte.adresse("homeassistant.local:8123/"), "http://homeassistant.local:8123")
    }

    func testAblageRundreise() throws {
        let u = beispiel()
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .secondsSince1970
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
        let zurueck = try dec.decode(Uebersicht.self, from: enc.encode(u))
        XCTAssertEqual(zurueck.sendungen.map(\.id), u.sendungen.map(\.id))
        XCTAssertEqual(zurueck.sendungen[0].ereignisse, u.sendungen[0].ereignisse)
    }
}
