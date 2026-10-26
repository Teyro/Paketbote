.pragma library
.import "uebersetzung.js" as U

// Übersetzen: Schlüssel ist der deutsche Text; %1, %2 … werden ersetzt. Deutsch bei deutscher Systemsprache, sonst Englisch.
var tabelle = String(Qt.locale().name).indexOf("de") === 0 ? {} : U.EN;

function setzeSprache(code) { tabelle = code === "de" ? {} : U.EN; }

function t(text) {
    var s = tabelle[text] || text;
    for (var i = arguments.length - 1; i >= 1; i--) s = s.split("%" + i).join(String(arguments[i]));
    return s;
}
