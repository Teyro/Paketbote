.pragma library
.import "sprache.js" as S

// Gemeinsame Logik der Linux-App und des Plasma-Widgets (wie PaketKern der Apple-Apps).

var t = S.t;

var DIENSTE = {
    dhl: { name: "DHL", farbe: "#FFCC00", schrift: "#D40511" },
    hermes: { name: "Hermes", farbe: "#0091CD", schrift: "#FFFFFF" },
    dpd: { name: "DPD", farbe: "#DC0032", schrift: "#FFFFFF" },
    gls: { name: "GLS", farbe: "#10337A", schrift: "#FFD900" },
    ups: { name: "UPS", farbe: "#40291A", schrift: "#FFB500" },
    amazon: { name: "Amazon", farbe: "#232F3E", schrift: "#FF9900" }
};
var ALLE = ["dhl", "hermes", "dpd", "gls", "ups", "amazon"];

function dienst(d) { return DIENSTE[d] || { name: String(d || "").toUpperCase(), farbe: "#B8854D", schrift: "#FFFFFF" }; }

/** Dienst an der Nummer erkennen ("" = nicht eindeutig, z. B. 14 Ziffern bei Hermes und DPD) */
function dienstVonNummer(nummer) {
    var n = String(nummer || "").replace(/\s+/g, "").toUpperCase();
    if (/^(TBA\d{9,14}|\d{3}-\d{7}-\d{7})$/.test(n)) return "amazon";
    if (/^(JJD\d{12,20}|00\d{18}|\d{20}|\d{12})$/.test(n)) return "dhl";
    if (/^H[0-9A-Z]{19}$/.test(n)) return "hermes";
    if (/^1Z[0-9A-Z]{16}$/.test(n)) return "ups";
    return "";
}

/** Sendungsnummer in einem Text (z. B. aus der Zwischenablage) */
function nummerIn(text) {
    var m = String(text || "").toUpperCase().match(/TBA\d{9,14}|\d{3}-\d{7}-\d{7}|JJD\d{12,20}|1Z[0-9A-Z]{16}|H[0-9A-Z]{19}|\d{11,20}/);
    return m ? m[0] : "";
}

function verfolgenAdresse(s) {
    if (/^https:\/\//.test(s.verfolgen || "")) return s.verfolgen;
    var n = encodeURIComponent(s.nummer || "");
    if (!n) return "";
    switch (s.dienst) {
    case "hermes": return "https://www.myhermes.de/empfangen/sendungsverfolgung/sendungsinformation#" + n;
    case "dpd": return "https://tracking.dpd.de/status/de_DE/parcel/" + n;
    case "gls": return "https://gls-group.com/DE/de/paketverfolgung?match=" + n;
    case "ups": return "https://www.ups.com/track?loc=de_DE&tracknum=" + n;
    case "amazon": return "https://track.amazon.de/tracking/" + n;
    default: return "https://www.dhl.de/de/privatkunden/pakete-empfangen/verfolgen.html?piececode=" + n;
    }
}

/** Antwort von /api/briefankuendigung/briefe → nur die Pakete, mit festen Feldern */
function sendungenAus(antwort) {
    return ((antwort && antwort.briefe) || []).filter(function (b) { return b.art === "paket"; }).map(function (b) {
        return {
            id: b.id, datum: b.datum || 0, absender: b.absender || "", name: b.name || "", nummer: b.sendung || "",
            dienst: b.dienst || "dhl", dienstName: b.dienst_name || dienst(b.dienst || "dhl").name, stand: b.stand || "unterwegs",
            erwartet: b.erwartet || "", zeitfenster: b.zeitfenster || "", kundenkonto: b.kundenkonto || "", verfolgen: b.verfolgen || "",
            manuell: !!b.manuell, statusText: b.status_text || "", problem: !!b.problem, erledigt: !!b.erledigt,
            kontoId: b.konto || "", kontoName: b.konto_name || "", anbieter: b.anbieter || "", quelle: "ha", ruecksendung: !!b.ruecksendung,
            ereignisse: (b.ereignisse || []).filter(function (e) { return e && e.text; })
                .map(function (e) { return { zeit: e.zeit ? Date.parse(e.zeit) || 0 : 0, text: e.text, ort: e.ort || "" }; })
        };
    });
}

function titel(s) { return s.name || s.absender || s.nummer || t("Paket"); }
function fertig(s) { return s.stand === "zugestellt" || s.erledigt; }

function isoTag(ms) {
    var d = new Date(ms);
    return d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2);
}

function kommtHeute(s, jetzt) {
    return !fertig(s) && (s.stand === "heute" || s.stand === "abholbereit" || (!!s.erwartet && s.erwartet === isoTag(jetzt)));
}

/** 1…4: angekündigt · unterwegs · in Zustellung/abholbereit · zugestellt */
function stufe(s) {
    if (s.stand === "zugestellt") return 4;
    if (s.stand === "heute" || s.stand === "abholbereit") return 3;
    return s.ereignisse && s.ereignisse.length ? 2 : 1;
}

/** {heute, unterwegs, zugestellt, aktiv} – zugestellte der letzten `tage` Tage */
function gruppen(liste, jetzt, tage) {
    var g = { heute: [], unterwegs: [], zugestellt: [] };
    var grenze = jetzt - (tage || 14) * 86400000;
    (liste || []).forEach(function (s) {
        if (fertig(s)) { if (s.datum >= grenze) g.zugestellt.push(s); }
        else if (kommtHeute(s, jetzt)) g.heute.push(s);
        else g.unterwegs.push(s);
    });
    function termin(a, b) {
        var x = a.erwartet || "9999", y = b.erwartet || "9999";
        return x !== y ? (x < y ? -1 : 1) : b.datum - a.datum;
    }
    g.heute.sort(function (a, b) {
        var aa = a.stand === "abholbereit", bb = b.stand === "abholbereit";
        return aa !== bb ? (aa ? 1 : -1) : termin(a, b);
    });
    g.unterwegs.sort(termin);
    g.zugestellt.sort(function (a, b) { return b.datum - a.datum; });
    g.aktiv = g.heute.concat(g.unterwegs);
    return g;
}

var TAGE = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"];

/** „kommt morgen, 10:00–13:00“, „voraussichtlich Fr 23.10.“, „zur Abholung bereit“ */
function standText(s, jetzt) {
    if (s.stand === "zugestellt") return t("zugestellt");
    if (s.erledigt) return t("angekommen");
    if (s.stand === "abholbereit") return t("zur Abholung bereit");
    var f = s.zeitfenster ? ", " + s.zeitfenster : "";
    var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s.erwartet || "");
    if (m) {
        var d = new Date(+m[1], +m[2] - 1, +m[3]), h = new Date(jetzt);
        var tage = Math.round((d - new Date(h.getFullYear(), h.getMonth(), h.getDate())) / 86400000);
        var tm = d.getDate() + "." + (d.getMonth() + 1) + ".";
        if (tage === 0) return t("kommt heute") + f;
        if (tage === 1) return t("kommt morgen") + f;
        if (tage < 0) return s.stand === "heute" ? t("kommt heute") + f : t("überfällig seit %1", tm);
        return t("voraussichtlich %1", tage < 7 ? t(TAGE[d.getDay()]) + " " + tm : tm) + f;
    }
    if (s.stand === "heute") return t("kommt heute") + f;
    if (s.problem) return t("Problem bei der Zustellung");
    return s.ereignisse && s.ereignisse.length ? t("unterwegs") : t("angekündigt");
}

/** Stand · Kundenkonto (bzw. Postfach) */
function zeile(s, jetzt, mitKonto) {
    var teile = [standText(s, jetzt)];
    if (s.kundenkonto) teile.push(s.kundenkonto); else if (mitKonto && s.kontoName) teile.push(s.kontoName);
    return teile.join(" · ");
}

function anzahl(n) { return n === 1 ? t("1 Paket") : t("%1 Pakete", n); }
function kopfTitel(aktiv) { return aktiv.length ? t("%1 unterwegs", anzahl(aktiv.length)) : t("Keine Pakete unterwegs"); }

/** „heute 07:12“, „gestern 18:00“, „Di 20.10. 18:00“ */
function ereigniszeit(ms, jetzt) {
    if (!ms) return "";
    var d = new Date(ms), h = new Date(jetzt);
    var uhr = ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2);
    if (d.toDateString() === h.toDateString()) return t("heute %1", uhr);
    var g = new Date(jetzt - 86400000);
    if (d.toDateString() === g.toDateString()) return t("gestern %1", uhr);
    return t(TAGE[d.getDay()]) + " " + d.getDate() + "." + (d.getMonth() + 1) + ". " + uhr;
}

/** Mitteilung bei neuem Stand: {titel, text} oder null */
function mitteilung(alt, neu) {
    var text = titel(neu) + " (" + neu.dienstName + ")";
    if (neu.problem && !(alt && alt.problem)) return { titel: t("⚠️ Problem mit der Sendung"), text: text + (neu.statusText ? " – " + neu.statusText : "") };
    if (!alt || alt.stand === neu.stand || neu.erledigt) return null;
    var titelText = { heute: t("📦 Kommt heute"), abholbereit: t("📦 Zur Abholung bereit"), zugestellt: t("📦 Zugestellt") }[neu.stand];
    return titelText ? { titel: titelText, text: text } : null;
}

/** "homeassistant.local:8123/" → "http://homeassistant.local:8123" */
function adresse(a) {
    var s = String(a || "").trim().replace(/\/+$/, "");
    if (s && s.indexOf("://") < 0) s = "http://" + s;
    return s;
}

/** Farbe der Standzeile (Kirigami-Farben werden im QML eingesetzt): "heute" | "abholbereit" | "problem" | "" */
function standArt(s, jetzt) {
    if (s.problem) return "problem";
    if (s.stand === "abholbereit") return "abholbereit";
    return kommtHeute(s, jetzt) ? "heute" : "";
}

/** Sendungen aus Home Assistant und direkt verfolgte zusammenführen (gleiche Nummer: Home Assistant gewinnt, Verlauf ergänzt) */
function zusammenfuehren(ha, direkt) {
    var erg = (ha || []).map(function (s) { return Object.assign({ quelle: "ha" }, s); });
    (direkt || []).forEach(function (d) {
        var i = -1;
        for (var k = 0; k < erg.length; k++) if (d.nummer && String(erg[k].nummer).toUpperCase() === d.nummer) { i = k; break; }
        if (i < 0) { erg.push(d); return; }
        var h = Object.assign({}, erg[i]);
        // Die eigene Abfrage weiß mehr (Verlauf, weiterer Stand): deren Stand übernehmen
        if (d.ereignisse.length && (!h.ereignisse.length || stufe(d) > stufe(h))) {
            h.stand = d.stand; h.problem = d.problem; h.ereignisse = d.ereignisse; h.anbieter = d.anbieter;
            if (d.statusText) h.statusText = d.statusText;
            if (d.zeitfenster) h.zeitfenster = d.zeitfenster;
            h.datum = Math.max(h.datum, d.datum);
        }
        if (!h.ereignisse.length) h.ereignisse = d.ereignisse;
        if (!h.erwartet) h.erwartet = d.erwartet;
        if (!h.name) h.name = d.name;
        h.ruecksendung = h.ruecksendung || d.ruecksendung;
        if (!h.anbieter) h.anbieter = d.anbieter;
        erg[i] = h;
    });
    return erg;
}
