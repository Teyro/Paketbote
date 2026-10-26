// Verteilt i18n/en.json: Apple (ressourcen/i18n/en.json, <de|en>.lproj/Localizable.strings) und Linux (linux/gemeinsam/uebersetzung.js)
// Aufruf: node werkzeuge/baue-uebersetzungen.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const wurzel = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const esc = (s) => s.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n');
const strings = (tab) => Object.entries(tab).filter(([, v]) => v).map(([k, v]) => `"${esc(k)}" = "${esc(v)}";`).join('\n') + '\n';
const en = JSON.parse(fs.readFileSync(path.join(wurzel, 'i18n/en.json'), 'utf8'));
for (const [lproj, tab] of [['de', Object.fromEntries(Object.keys(en).map((k) => [k, k]))], ['en', en]]) {
  const o = path.join(wurzel, 'apple/ressourcen/sprachen', lproj + '.lproj');
  fs.mkdirSync(o, { recursive: true });
  fs.writeFileSync(path.join(o, 'Localizable.strings'), strings(tab));
}
fs.mkdirSync(path.join(wurzel, 'apple/ressourcen/i18n'), { recursive: true });
fs.copyFileSync(path.join(wurzel, 'i18n/en.json'), path.join(wurzel, 'apple/ressourcen/i18n/en.json'));
// Linux (QML): als JavaScript-Bibliothek
fs.mkdirSync(path.join(wurzel, 'linux/gemeinsam'), { recursive: true });
fs.writeFileSync(path.join(wurzel, 'linux/gemeinsam/uebersetzung.js'), '.pragma library\n// erzeugt von werkzeuge/baue-uebersetzungen.mjs – nicht von Hand ändern\nvar EN = ' + JSON.stringify(en, null, 1) + ';\n');
console.log('Übersetzungen gebaut: en');
