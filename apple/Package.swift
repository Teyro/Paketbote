// swift-tools-version: 6.0
import PackageDescription

// Der gemeinsame Kern von iPhone- und Mac-App (Sendungen, Texte, Home Assistant) – mit XCTest geprüft.
// Apps und Widgets baut das Xcode-Projekt (project.yml, erzeugt mit XcodeGen).
let package = Package(
    name: "Paketbote",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "PaketKern", targets: ["PaketKern"])],
    targets: [
        .target(name: "PaketKern"),
        .testTarget(name: "PaketKernTests", dependencies: ["PaketKern"]),
    ],
    swiftLanguageModes: [.v5]
)
