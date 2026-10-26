import SwiftUI
import MapKit
import CoreLocation
import PhotosUI
import PaketKern
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Eine Sendung: Kopf mit Logo und Stand, Karte der Stationen, Verlauf, Aktionen
struct DetailAnsicht: View {
    let kern: Kern
    let sendung: Sendung
    @State private var umbenennen = false
    @State private var neuerName = ""
    @State private var notiz = ""
    @State private var fotoWahl: PhotosPickerItem?
    @State private var foto: Image?
    @State private var fragt = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                kopf
                if !sendung.ereignisse.filter({ !$0.ort.isEmpty }).isEmpty {
                    StationenKarte(ereignisse: sendung.ereignisse)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                knoepfe
                verlauf
                notizUndFoto
                angaben
            }
            .padding()
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(sendung.titel)
        .task(id: sendung.id) {
            notiz = kern.notiz(sendung.id)
            fotoLaden()
            fragt = true
            await kern.jetztAbfragen(sendung)
            fragt = false
        }
        .onChange(of: fotoWahl) { _, neu in
            Task {
                guard let d = try? await neu?.loadTransferable(type: Data.self) else { return }
                try? FotoAblage.speichern(d, sendung.id)
                fotoLaden()
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem {
                ShareLink(item: teilenText) { Label(T("Teilen"), systemImage: "square.and.arrow.up") }
            }
        }
        .alert(T("Umbenennen"), isPresented: $umbenennen) {
            TextField(T("Name"), text: $neuerName)
            Button(T("Sichern")) { Task { await kern.umbenennen(sendung, neuerName) } }
            Button(T("Abbrechen"), role: .cancel) {}
        } message: {
            Text(T("Leer lassen, um wieder den Absender zu zeigen."))
        }
    }

    private var teilenText: String {
        [sendung.titel + " (\(sendung.dienstName))", sendung.nummer.isEmpty ? "" : T("Sendung %1", sendung.nummer), sendung.verfolgenURL?.absoluteString ?? ""]
            .filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private var kopf: some View {
        HStack(alignment: .top, spacing: 14) {
            DienstLogo(dienst: sendung.dienst, groesse: 64)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if sendung.ruecksendung { Etikett(text: T("Rücksendung"), farbe: .purple) }
                    if fragt { ProgressView().controlSize(.small) }
                }
                Text(sendung.titel).font(.title2.weight(.bold)).lineLimit(2)
                if !sendung.name.isEmpty && !sendung.absender.isEmpty && sendung.name != sendung.absender {
                    Text(sendung.absender).font(.subheadline).foregroundStyle(.secondary)
                }
                Text(Texte.stand(sendung))
                    .font(.headline)
                    .foregroundStyle(standFarbe(sendung))
                if !sendung.statusText.isEmpty {
                    Text(sendung.statusText).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Fortschritt(sendung: sendung, hoehe: 6).padding(.top, 2)
                HStack {
                    Text(T("angekündigt")); Spacer(); Text(T("unterwegs")); Spacer(); Text(T("in Zustellung")); Spacer(); Text(T("zugestellt"))
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
        }
    }

    private var knoepfe: some View {
        HStack(spacing: 10) {
            if let u = sendung.verfolgenURL {
                Link(destination: u) { Label(T("Beim Dienst"), systemImage: "safari").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered)
            }
            if sendung.erledigt {
                Button { Task { await kern.erledigt(sendung, false) } } label: {
                    Label(T("Doch nicht da"), systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered)
            } else if !sendung.fertig {
                Button { Task { await kern.erledigt(sendung, true) } } label: {
                    Label(T("Angekommen"), systemImage: "checkmark").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent)
            }
            Menu {
                Button { neuerName = sendung.name; umbenennen = true } label: { Label(T("Umbenennen"), systemImage: "pencil") }
                if !sendung.nummer.isEmpty {
                    Button { Zwischenablage.kopieren(sendung.nummer); kern.meldung = T("Nummer kopiert") } label: {
                        Label(T("Nummer kopieren"), systemImage: "doc.on.doc")
                    }
                }
                if sendung.manuell {
                    Button(role: .destructive) { Task { await kern.entfernen(sendung) } } label: { Label(T("Entfernen"), systemImage: "trash") }
                }
            } label: {
                Image(systemName: "ellipsis").frame(width: 28, height: 20)
            }
            .menuIndicator(.hidden)
            .fixedSize()
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
    }

    @ViewBuilder
    private var verlauf: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(T("Verlauf")).font(.headline).padding(.bottom, 8)
            if sendung.ereignisse.isEmpty {
                Text(sendung.verfolgenURL == nil ? T("Noch keine Stationen bekannt.")
                     : T("Noch keine Stationen bekannt. Den genauen Verlauf zeigt die Seite des Dienstes – oder unter Einstellungen → Direkt verfolgen einen Anbieter eintragen."))
                    .font(.callout).foregroundStyle(.secondary)
                if !kern.anbieterFehler.isEmpty && !fragt {
                    ForEach(kern.anbieterFehler.sorted(by: { $0.key < $1.key }), id: \.key) { e in
                        Label("\(e.key): \(e.value)", systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            ForEach(Array(sendung.ereignisse.enumerated()), id: \.element.id) { i, e in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(i == 0 ? Color.accentColor : Color.secondary.opacity(0.5))
                            .frame(width: 11, height: 11)
                            .padding(.top, 4)
                        if i < sendung.ereignisse.count - 1 {
                            Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 2)
                        }
                    }
                    .frame(width: 12)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.text).font(i == 0 ? .body.weight(.semibold) : .body)
                        Text([Texte.ereigniszeit(e.zeit), e.ort].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 14)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Notiz und Foto (bleiben auf diesem Gerät)
    private var notizUndFoto: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(T("Notiz und Foto")).font(.headline)
            TextField(T("z. B. „Beim Nachbarn abgegeben“"), text: $notiz, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
                .onSubmit { kern.notizSetzen(sendung.id, notiz) }
                .onChange(of: notiz) { _, t in kern.notizSetzen(sendung.id, t) }
            HStack {
                PhotosPicker(selection: $fotoWahl, matching: .images) {
                    Label(foto == nil ? T("Foto hinzufügen") : T("Foto ersetzen"), systemImage: "photo")
                }
                if foto != nil {
                    Button(role: .destructive) { FotoAblage.loeschen(sendung.id); foto = nil } label: { Label(T("Foto entfernen"), systemImage: "trash") }
                }
            }
            .buttonStyle(.bordered)
            if let foto {
                foto.resizable().scaledToFit().frame(maxHeight: 260).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func fotoLaden() {
        foto = FotoAblage.bild(sendung.id)
    }

    private var angaben: some View {
        VStack(alignment: .leading, spacing: 6) {
            zeile(T("Dienst"), sendung.dienstName)
            zeile(T("Quelle"), sendung.quelle == "direkt" ? T("direkt verfolgt") + (sendung.anbieter.isEmpty ? "" : " · " + sendung.anbieter)
                              : T("Home Assistant") + (sendung.anbieter.isEmpty ? "" : " · " + sendung.anbieter))
            if !sendung.nummer.isEmpty { zeile(T("Sendungsnummer"), sendung.nummer) }
            if !sendung.kundenkonto.isEmpty { zeile(T("Kundenkonto"), sendung.kundenkonto) }
            if kern.mehrereKonten && !sendung.kontoName.isEmpty { zeile(T("Postfach"), sendung.kontoName) }
            zeile(T("Letzte Meldung"), sendung.datum.formatted(date: .abbreviated, time: .shortened))
            if sendung.manuell { zeile(T("Hinzugefügt"), T("von Hand")) }
        }
        .font(.callout)
        .textSelection(.enabled)
    }

    private func zeile(_ a: String, _ b: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(a).foregroundStyle(.secondary).frame(width: 130, alignment: .leading)
            Text(b)
            Spacer(minLength: 0)
        }
    }
}

/// Karte mit den Orten aus dem Verlauf (Orte werden nachgeschlagen und gemerkt)
struct StationenKarte: View {
    let ereignisse: [Ereignis]
    @State private var punkte: [(ort: String, koordinate: CLLocationCoordinate2D)] = []

    var body: some View {
        Map {
            ForEach(Array(punkte.enumerated()), id: \.offset) { i, p in
                Marker(p.ort, systemImage: i == 0 ? "shippingbox.fill" : "circle.fill", coordinate: p.koordinate)
                    .tint(i == 0 ? Color.accentColor : .gray)
            }
            if punkte.count > 1 {
                MapPolyline(coordinates: punkte.reversed().map(\.koordinate)).stroke(Color.accentColor.opacity(0.7), lineWidth: 3)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .task(id: ereignisse.map(\.ort).joined()) { await nachschlagen() }
        .overlay { if punkte.isEmpty { ProgressView() } }
    }

    private func nachschlagen() async {
        var orte: [String] = []
        for e in ereignisse where !e.ort.isEmpty && !orte.contains(e.ort) { orte.append(e.ort) }
        var neu: [(String, CLLocationCoordinate2D)] = []
        for ort in orte.prefix(8) {
            if let k = await Orte.koordinate(ort) { neu.append((ort, k)) }
        }
        punkte = neu
    }
}

/// Orte nachschlagen (mit Zwischenspeicher – Apple begrenzt die Anfragen)
@MainActor
enum Orte {
    static var gemerkt: [String: CLLocationCoordinate2D] = [:]

    static func koordinate(_ ort: String) async -> CLLocationCoordinate2D? {
        if let k = gemerkt[ort] { return k }
        let d = UserDefaults.standard
        if let a = d.array(forKey: "ort2." + ort) as? [Double], a.count == 2 {
            let k = CLLocationCoordinate2D(latitude: a[0], longitude: a[1])
            gemerkt[ort] = k
            return k
        }
        // Mitteleuropa bevorzugen („Hamburg“ ist sonst womöglich Hamburg in New York)
        let europa = CLCircularRegion(center: CLLocationCoordinate2D(latitude: 50.5, longitude: 10.5), radius: 1_200_000, identifier: "europa")
        guard let ergebnis = try? await CLGeocoder().geocodeAddressString(ort, in: europa) else { return nil }
        let nah = ergebnis.first { p in p.location.map { europa.contains($0.coordinate) } ?? false }
        guard let k = (nah ?? ergebnis.first)?.location?.coordinate else { return nil }
        gemerkt[ort] = k
        d.set([k.latitude, k.longitude], forKey: "ort2." + ort)
        return k
    }
}

/// Fotos zu Sendungen (JPEG auf dem Gerät)
enum FotoAblage {
    static func speichern(_ daten: Data, _ id: String) throws {
        #if canImport(UIKit)
        let jpeg = UIImage(data: daten).flatMap { $0.jpegData(compressionQuality: 0.8) } ?? daten
        #else
        let jpeg = NSBitmapImageRep(data: daten)?.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) ?? daten
        #endif
        try jpeg.write(to: DirektListe.foto(id), options: .atomic)
    }

    static func bild(_ id: String) -> Image? {
        guard let d = try? Data(contentsOf: DirektListe.foto(id)) else { return nil }
        #if canImport(UIKit)
        return UIImage(data: d).map { Image(uiImage: $0) }
        #else
        return NSImage(data: d).map { Image(nsImage: $0) }
        #endif
    }

    static func loeschen(_ id: String) { try? FileManager.default.removeItem(at: DirektListe.foto(id)) }
}
