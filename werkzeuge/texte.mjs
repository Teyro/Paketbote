// Sammelt alle zu übersetzenden Texte aus Apple-Apps (T("…")) und Linux-App (t("…")) und gleicht i18n/en.json ab
// (neue Texte leer, entfallene werden entfernt). Aufruf: node werkzeuge/texte.mjs [--streng]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const wurzel = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
function dateien(ordner, endungen) {
  if (!fs.existsSync(ordner)) return [];
  const aus = [];
  for (const e of fs.readdirSync(ordner, { withFileTypes: true })) {
    const p = path.join(ordner, e.name);
    if (e.isDirectory()) aus.push(...dateien(p, endungen));
    else if (endungen.some((x) => e.name.endsWith(x))) aus.push(p);
  }
  return aus;
}
const unescape = (s) => s.replace(/\\"/g, '"').replace(/\\n/g, '\n').replace(/\\\\/g, '\\');
const texte = new Set();
for (const f of dateien(path.join(wurzel, 'linux'), ['.qml', '.js'])) {
  for (const m of fs.readFileSync(f, 'utf8').matchAll(/\b(?:i18n|t)\(\s*"((?:[^"\\]|\\.)*)"/g)) texte.add(unescape(m[1]));
}
for (const f of dateien(path.join(wurzel, 'apple/Sources'), ['.swift'])) {
  for (const m of fs.readFileSync(f, 'utf8').matchAll(/\bT\(\s*"((?:[^"\\]|\\.)*)"/g)) if (!m[1].includes('\\(')) texte.add(unescape(m[1]));
}
const datei = path.join(wurzel, 'i18n/en.json');
const alt = fs.existsSync(datei) ? JSON.parse(fs.readFileSync(datei, 'utf8')) : {};
const neu = {};
for (const t of [...texte].filter((t) => t.trim()).sort((a, b) => a.localeCompare(b, 'de'))) neu[t] = alt[t] || '';
fs.writeFileSync(datei, JSON.stringify(neu, null, 1) + '\n');
const fehlt = Object.entries(neu).filter(([, v]) => !v).map(([k]) => k);
console.log(`en: ${Object.keys(neu).length - fehlt.length}/${Object.keys(neu).length} übersetzt`);
if (fehlt.length) { console.log(fehlt.map((k) => '  ' + JSON.stringify(k)).join('\n')); if (process.argv.includes('--streng')) process.exit(1); }
