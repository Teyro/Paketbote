import SwiftUI
import VisionKit
import PaketKern

/// Paketschein scannen: Barcode (oder Text) mit der Kamera – die erste Sendungsnummer gewinnt
struct Scanner: UIViewControllerRepresentable {
    let gefunden: (String) -> Void

    static var moeglich: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let v = DataScannerViewController(recognizedDataTypes: [.barcode(), .text()], qualityLevel: .balanced,
                                          recognizesMultipleItems: true, isHighFrameRateTrackingEnabled: false, isHighlightingEnabled: true)
        v.delegate = context.coordinator
        try? v.startScanning()
        return v
    }

    func updateUIViewController(_ v: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Koordinator { Koordinator(gefunden: gefunden) }

    final class Koordinator: NSObject, DataScannerViewControllerDelegate {
        let gefunden: (String) -> Void
        var fertig = false
        init(gefunden: @escaping (String) -> Void) { self.gefunden = gefunden }

        func dataScanner(_ s: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            // Barcodes zuerst – Text nur, wenn darin eine Nummer steht
            var codes: [String] = [], texte: [String] = []
            for item in allItems {
                switch item {
                case .barcode(let b): if let p = b.payloadStringValue { codes.append(p) }
                case .text(let t): texte.append(t.transcript)
                @unknown default: break
                }
            }
            let texte2 = codes + texte
            guard !fertig, let n = texte2.lazy.compactMap({ Dienst.nummerIn($0) }).first else { return }
            fertig = true
            s.stopScanning()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            gefunden(n)
        }
    }
}

/// Scanner als Blatt mit Hinweis und Abbrechen
struct ScannerBlatt: View {
    let gefunden: (String) -> Void
    @Environment(\.dismiss) private var schliessen
    var body: some View {
        NavigationStack {
            Scanner { n in gefunden(n); schliessen() }
                .ignoresSafeArea()
                .overlay(alignment: .bottom) {
                    Text(T("Barcode oder Sendungsnummer auf dem Paketschein ins Bild halten."))
                        .font(.callout.weight(.medium))
                        .padding(12)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 30)
                }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(T("Abbrechen")) { schliessen() } } }
        }
    }
}
