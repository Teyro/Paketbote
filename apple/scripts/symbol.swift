// App-Symbol zeichnen: weißer Brief und gelbes Paket auf blauem Verlauf („Post & Pakete“).
// Aufruf: swift scripts/symbol.swift <Ordner.iconset> <AppIcon-1024.png>
import AppKit
import ImageIO

let ordner = CommandLine.arguments[1]
let gross = CommandLine.arguments[2]
try? FileManager.default.createDirectory(atPath: ordner, withIntermediateDirectories: true)

/// rand: macOS-Symbole haben Luft drumherum, iOS-Symbole füllen die Fläche (iOS rundet selbst ab)
func bild(_ px: Int, mac: Bool) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
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
    // Brief (hinten, leicht gedreht) und Paket (vorn rechts) – „Post & Pakete“
    let brief = NSImage.SymbolConfiguration(pointSize: s * 0.36, weight: .semibold).applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let sym = NSImage(systemSymbolName: "envelope.fill", accessibilityDescription: nil)?.withSymbolConfiguration(brief), let ctx = NSGraphicsContext.current?.cgContext {
        let g = sym.size
        ctx.saveGState()
        ctx.translateBy(x: s * 0.4, y: s * 0.58)
        ctx.rotate(by: 8 * .pi / 180)
        sym.draw(in: NSRect(x: -g.width / 2, y: -g.height / 2, width: g.width, height: g.height))
        ctx.restoreGState()
    }
    // Paket mit dunklem Rand, damit es sich vom Brief abhebt
    let umriss = NSImage.SymbolConfiguration(pointSize: s * 0.36, weight: .black).applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(red: 0.12, green: 0.25, blue: 0.72, alpha: 1)]))
    let paket = NSImage.SymbolConfiguration(pointSize: s * 0.32, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1)]))
    if let r = NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: nil)?.withSymbolConfiguration(umriss),
       let p = NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: nil)?.withSymbolConfiguration(paket) {
        let mitte = NSPoint(x: s * 0.62, y: s * 0.36)
        r.draw(in: NSRect(x: mitte.x - r.size.width / 2, y: mitte.y - r.size.height / 2, width: r.size.width, height: r.size.height))
        p.draw(in: NSRect(x: mitte.x - p.size.width / 2, y: mitte.y - p.size.height / 2, width: p.size.width, height: p.size.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (groesse, faktor) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let name = faktor == 1 ? "icon_\(groesse)x\(groesse).png" : "icon_\(groesse)x\(groesse)@2x.png"
    try! bild(groesse * faktor, mac: true).write(to: URL(fileURLWithPath: "\(ordner)/\(name)"))
}
// iOS will ein Symbol ohne Transparenz: auf eine Fläche ohne Alphakanal übertragen
// (direkt in ein RGB-Bild ohne Alpha zu zeichnen geht nicht – AppKit bekommt dafür keine Zeichenfläche, das Bild bliebe schwarz)
let rgba = NSBitmapImageRep(data: bild(1024, mac: false))!.cgImage!
let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.draw(rgba, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
let ohneAlpha = ctx.makeImage()!
let ziel = CGImageDestinationCreateWithURL(URL(fileURLWithPath: gross) as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(ziel, ohneAlpha, nil)
precondition(CGImageDestinationFinalize(ziel), "Symbol konnte nicht geschrieben werden")
