// Prüft linux/gemeinsam/logik.js ohne Qt: node linux/test/logik-test.mjs
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const ordner = new URL('../gemeinsam/', import.meta.url);
const lies = (n) => fs.readFileSync(new URL(n, ordner), 'utf8').replace(/^\.(pragma|import).*$/gm, '');
function laden(sprache) {
  const ctx = { Qt: { locale: () => ({ name: sprache }) }, console };
  vm.createContext(ctx);
  vm.runInContext(lies('uebersetzung.js') + '\nvar U = { EN: EN };\n' + lies('sprache.js') + '\nvar S = { t: t };\n' + lies('logik.js'), ctx);
  return ctx;
}
const L = laden('de_DE');
const jetzt = new Date(2026, 9, 21, 9).getTime();
const antwort = { briefe: [
  { id: 'p1', datum: jetzt, art: 'paket', absender: 'OTTO', sendung: 'H1002345678901234567', dienst: 'hermes', erwartet: '2026-10-23', zeitfenster: '10:00–13:00',
    ereignisse: [{ zeit: '2026-10-20T18:00:00+02:00', text: 'Im Verteilzentrum', ort: 'Ketzin' }] },
  { id: 'p2', datum: jetzt, art: 'paket', absender: 'Zalando', dienst: 'dpd', stand: 'heute' },
  { id: 'p3', datum: jetzt, art: 'paket', absender: 'Kindle', name: 'Geschenk Oma', dienst: 'amazon', erwartet: '2026-10-22', kundenkonto: 'Johanna' },
  { id: 'p4', datum: jetzt, art: 'paket', absender: 'Alt', stand: 'zugestellt' },
  { id: 'p5', datum: jetzt, art: 'paket', absender: 'Kaffee', stand: 'abholbereit', dienst: 'gls' },
  { id: 'b1', datum: jetzt, art: 'brief', absender: 'AOK' },
] };
const s = L.sendungenAus(antwort);
assert.equal(s.length, 5);
const g = L.gruppen(s, jetzt, 14);
assert.equal(JSON.stringify(g.heute.map((x) => x.id)), JSON.stringify(['p2', 'p5']));
assert.equal(JSON.stringify(g.unterwegs.map((x) => x.id)), JSON.stringify(['p3', 'p1']));
assert.equal(JSON.stringify(g.zugestellt.map((x) => x.id)), JSON.stringify(['p4']));
assert.equal(L.standText(s[0], jetzt), 'voraussichtlich Fr 23.10., 10:00–13:00');
assert.equal(L.zeile(s[2], jetzt, false), 'kommt morgen · Johanna');
assert.equal(L.titel(s[2]), 'Geschenk Oma');
assert.equal(L.stufe(s[0]), 2);
assert.equal(L.kopfTitel(g.aktiv), '4 Pakete unterwegs');
assert.equal(L.dienstVonNummer('1Z999AA10123456784'), 'ups');
assert.equal(L.dienstVonNummer('01234567890123'), '');
assert.equal(L.nummerIn('Sendungsnummer: 00340434161094015902.'), '00340434161094015902');
assert.equal(L.verfolgenAdresse({ dienst: 'gls', nummer: '123' }), 'https://gls-group.com/DE/de/paketverfolgung?match=123');
assert.equal(L.mitteilung(s[0], Object.assign({}, s[0], { stand: 'heute' })).titel, '📦 Kommt heute');
assert.equal(L.mitteilung(s[0], s[0]), null);
assert.equal(L.adresse('homeassistant.local:8123/'), 'http://homeassistant.local:8123');
const E = laden('en_GB');
assert.equal(E.standText(E.sendungenAus(antwort)[2], jetzt), 'arrives tomorrow');
console.log('logik.js: alle Prüfungen bestanden');
