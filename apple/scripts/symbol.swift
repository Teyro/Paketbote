// App-Symbol zeichnen: weißer Karton auf blauem Verlauf, dazu ein gelber Haken-Kreis (angekommen).
// Aufruf: swift scripts/symbol.swift <Ordner.iconset> <AppIcon-1024.png>
import AppKit

let ordner = CommandLine.arguments[1]
let gross = CommandLine.arguments[2]
try? FileManager.default.createDirectory(atPath: ordner, withIntermediateDirectories: true)

/// rand: macOS-Symbole haben Luft drumherum, iOS-Symbole füllen die Fläche (iOS rundet selbst ab)
func bild(_ px: Int, mac: Bool) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: mac ? 4 : 3,
                               hasAlpha: mac, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let rand = mac ? s * 0.1 : 0
    let flaeche = NSRect(x: rand, y: rand, width: s - 2 * rand, height: s - 2 * rand)
    let form = mac ? NSBezierPath(roundedRect: flaeche, xRadius: flaeche.width * 0.225, yRadius: flaeche.width * 0.225) : NSBezierPath(rect: flaeche)
    NSGraphicsContext.current?.saveGraphicsState()
    if mac {
        let schatten = NSShadow()
        schatten.shadowColor = NSColor.black.withAlphaComponent(0.3)
        schatten.shadowOffset = NSSize(width: 0, height: -s * 0.01)
        schatten.shadowBlurRadius = s * 0.025
        schatten.set()
    }
    NSGradient(colors: [NSColor(red: 0.25, green: 0.56, blue: 1.0, alpha: 1), NSColor(red: 0.12, green: 0.3, blue: 0.85, alpha: 1)])!
        .draw(in: form, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.25), NSColor.white.withAlphaComponent(0)])!.draw(in: form, angle: -90)
    let konfig = NSImage.SymbolConfiguration(pointSize: s * 0.4, weight: .semibold).applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let sym = NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: nil)?.withSymbolConfiguration(konfig) {
        let g = sym.size
        sym.draw(in: NSRect(x: (s - g.width) / 2 - s * 0.03, y: (s - g.height) / 2 - s * 0.03, width: g.width, height: g.height))
    }
    let kreis = NSRect(x: s * 0.6, y: s * 0.58, width: s * 0.25, height: s * 0.25)
    NSColor(red: 0.12, green: 0.3, blue: 0.85, alpha: 1).setFill()
    NSBezierPath(ovalIn: kreis.insetBy(dx: -s * 0.018, dy: -s * 0.018)).fill()
    NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1).setFill()
    NSBezierPath(ovalIn: kreis).fill()
    let haken = NSImage.SymbolConfiguration(pointSize: s * 0.12, weight: .black)
        .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(red: 0.12, green: 0.2, blue: 0.5, alpha: 1)]))
    if let b = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)?.withSymbolConfiguration(haken) {
        let g = b.size
        b.draw(in: NSRect(x: kreis.midX - g.width / 2, y: kreis.midY - g.height / 2, width: g.width, height: g.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (groesse, faktor) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let name = faktor == 1 ? "icon_\(groesse)x\(groesse).png" : "icon_\(groesse)x\(groesse)@2x.png"
    try! bild(groesse * faktor, mac: true).write(to: URL(fileURLWithPath: "\(ordner)/\(name)"))
}
try! bild(1024, mac: false).write(to: URL(fileURLWithPath: gross))
