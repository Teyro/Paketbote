import SwiftUI
import PaketKern

// Bausteine, die App und Widgets gemeinsam nutzen: Logo des Dienstes, Fortschritt, Farben.

extension Color {
    init(_ rgb: (Double, Double, Double)) { self.init(red: rgb.0, green: rgb.1, blue: rgb.2) }
}

/// Logo des Paketdienstes: Name auf seiner Farbe, als abgerundetes Quadrat
struct DienstLogo: View {
    let dienst: String
    var groesse: CGFloat = 40

    var body: some View {
        let f = Dienst.farben(dienst)
        RoundedRectangle(cornerRadius: groesse * 0.26, style: .continuous)
            .fill(Color(f.hintergrund).gradient)
            .frame(width: groesse, height: groesse)
            .overlay {
                VStack(spacing: groesse * 0.02) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: groesse * 0.34, weight: .semibold))
                    Text(Dienst.name(dienst))
                        .font(.system(size: groesse * (Dienst.name(dienst).count > 4 ? 0.2 : 0.24), weight: .heavy))
                        .italic(dienst == "dhl")
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .foregroundStyle(Color(f.schrift))
                .padding(groesse * 0.06)
            }
            .accessibilityLabel(Dienst.name(dienst))
    }
}

/// Fortschritt in vier Schritten: angekündigt · unterwegs · in Zustellung · zugestellt
struct Fortschritt: View {
    let sendung: Sendung
    var hoehe: CGFloat = 5

    var body: some View {
        let farbe: Color = sendung.problem ? .orange : sendung.stufe == 4 ? .green : .accentColor
        HStack(spacing: 3) {
            ForEach(1...4, id: \.self) { i in
                Capsule()
                    .fill(i <= sendung.stufe ? AnyShapeStyle(farbe) : AnyShapeStyle(Color.primary.opacity(0.15)))
                    .frame(height: hoehe)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Texte.stand(sendung))
    }
}

/// Kleines farbiges Etikett, z. B. „Heute“
struct Etikett: View {
    let text: String
    var farbe: Color = .accentColor
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(farbe)
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(farbe.opacity(0.16), in: Capsule())
            .fixedSize()
    }
}

/// Farbe der Standzeile: heute blau, abholbereit orange, Problem rot
func standFarbe(_ s: Sendung) -> Color {
    if s.problem { return .red }
    if s.stand == "abholbereit" { return .orange }
    if s.kommtHeute() { return .accentColor }
    return .secondary
}
