// Nachgebautes Home Assistant mit der Integration „Briefankündigung“ (Schnittstelle 4) – für Tests und Bildschirmfotos
// (iPhone, Mac, Linux). Aufruf: node test/ha-mock.mjs [port]   Token: test-token (HA_MOCK_TOKEN)
import http from 'node:http';
import fs from 'node:fs';
import zlib from 'node:zlib';

const TOKEN = process.env.HA_MOCK_TOKEN || 'test-token';
const PORT = Number(process.argv[2] || 8123);
const LOG = process.env.HA_MOCK_LOG || '/tmp/paketbote-mock.log';
const log = (z) => { try { fs.appendFileSync(LOG, z + '\n'); } catch { /* egal */ } };

/** Briefumschlag als PNG (ohne Bibliothek): Papier, dunkler Kopf, Adresszeilen, Marke */
function umschlagPNG(b = 480, h = 300, n = 0) {
  const zeilen = [];
  for (let y = 0; y < h; y++) {
    const z = [0];
    for (let x = 0; x < b; x++) {
      let p = [246, 244, 238];
      if (y < 34) p = n % 2 ? [20, 60, 120] : [34, 34, 34];
      else if (y > 150 && y < 160 && x > 54 && x < 260 + n * 20) p = [60, 60, 60];
      else if ((y > 176 && y < 184 || y > 198 && y < 206) && x > 54 && x < 300) p = [100, 100, 100];
      else if (x > 370 && x < 436 && y > 56 && y < 122) p = n % 2 ? [40, 140, 70] : [200, 40, 40];
      z.push(...p);
    }
    zeilen.push(Buffer.from(z));
  }
  const tab = []; for (let k = 0; k < 256; k++) { let c = k; for (let j = 0; j < 8; j++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; tab[k] = c >>> 0; }
  const crc = (buf) => { let r = 0xffffffff; for (const x of buf) r = tab[(r ^ x) & 255] ^ (r >>> 8); return (r ^ 0xffffffff) >>> 0; };
  const block = (art, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const ad = Buffer.concat([Buffer.from(art), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(ad)); return Buffer.concat([l, ad, c]); };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(b, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 2;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), block('IHDR', ihdr), block('IDAT', zlib.deflateSync(Buffer.concat(zeilen))), block('IEND', Buffer.alloc(0))]);
}

const jetzt = Date.now();
const tag = (n) => { const d = new Date(Date.now() + n * 86400e3); return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); };
const zeit = (stunden) => new Date(jetzt - stunden * 3600e3).toISOString();
const NAMEN = { dhl: 'DHL', hermes: 'Hermes', dpd: 'DPD', gls: 'GLS', ups: 'UPS', amazon: 'Amazon' };
const VERFOLGEN = {
  dhl: (n) => 'https://www.dhl.de/de/privatkunden/pakete-empfangen/verfolgen.html?piececode=' + n,
  hermes: (n) => 'https://www.myhermes.de/empfangen/sendungsverfolgung/sendungsinformation#' + n,
  dpd: (n) => 'https://tracking.dpd.de/status/de_DE/parcel/' + n,
  gls: (n) => 'https://gls-group.com/DE/de/paketverfolgung?match=' + n,
  ups: (n) => 'https://www.ups.com/track?loc=de_DE&tracknum=' + n,
  amazon: (n) => 'https://track.amazon.de/tracking/' + n,
};
const paket = (o) => ({ art: 'paket', bild: false, konto: 'e1', konto_name: 'Kim', stand: 'unterwegs', dienst_name: NAMEN[o.dienst], verfolgen: VERFOLGEN[o.dienst](o.sendung), ...o });

const POST = {
  erledigt: new Set(), stand: jetzt - 2 * 3600e3, abrufe: 0,
  briefe: [
    paket({ id: 'c'.repeat(20), datum: jetzt - 3 * 3600e3, absender: 'Thalia Bücher GmbH', sendung: '00340434161094015902', stand: 'heute', dienst: 'dhl',
      erwartet: tag(0), zeitfenster: '10:00–13:00', status_text: 'Die Sendung wurde in das Zustellfahrzeug geladen.',
      ereignisse: [
        { zeit: zeit(3), text: 'Die Sendung wurde in das Zustellfahrzeug geladen.', ort: 'Hamburg' },
        { zeit: zeit(9), text: 'Die Sendung wurde im Start-Paketzentrum bearbeitet.', ort: 'Hamburg-Allermöhe' },
        { zeit: zeit(30), text: 'Die Sendung wurde im Paketzentrum bearbeitet.', ort: 'Bielefeld' },
        { zeit: zeit(40), text: 'Die Sendung wurde vom Absender in der Filiale eingeliefert.', ort: 'Gütersloh' },
      ] }),
    paket({ id: '3'.repeat(20), datum: jetzt - 2 * 3600e3, absender: 'Kaffeebohnen 1 kg', sendung: 'TBA309999999999', stand: 'abholbereit', dienst: 'amazon',
      kundenkonto: 'Kim', status_text: 'Liegt im Amazon Locker Bahnhof zur Abholung bereit',
      abholcode: '482913', abholort: 'Amazon Locker Bahnhof', abholadresse: 'Hachmannplatz 16, 20099 Hamburg', abholfrist: tag(3) }),
    paket({ id: '1'.repeat(20), datum: jetzt - 5 * 3600e3, absender: 'OTTO GmbH & Co KG', name: 'Laufschuhe', sendung: 'H1002345678901234567', dienst: 'hermes',
      erwartet: tag(2), zeitfenster: '10:00–13:00',
      ereignisse: [
        { zeit: zeit(5), text: 'Die Sendung ist im Hermes Verteilzentrum eingetroffen.', ort: 'Ketzin' },
        { zeit: zeit(28), text: 'Die Sendung wurde an Hermes übergeben.', ort: 'Haldensleben' },
      ] }),
    paket({ id: '2'.repeat(20), datum: jetzt - 20 * 3600e3, absender: 'Kindle Paperwhite (16 GB)', sendung: 'TBA301234567890', dienst: 'amazon', erwartet: tag(1),
      kundenkonto: 'Johanna' }),
    paket({ id: '4'.repeat(20), datum: jetzt - 8 * 3600e3, absender: 'Fahrradladen Nord', sendung: '1Z999AA10123456784', dienst: 'ups', erwartet: tag(4), manuell: true,
      ereignisse: [{ zeit: zeit(8), text: 'Auftrag verarbeitet: bereit für UPS', ort: 'Köln' }] }),
    paket({ id: '5'.repeat(20), datum: jetzt - 30 * 3600e3, absender: 'Manufactum', sendung: '73012345678', dienst: 'gls', problem: true,
      status_text: 'Zustellung nicht möglich – Empfänger nicht angetroffen', ereignisse: [{ zeit: zeit(30), text: 'Zustellung nicht möglich – Empfänger nicht angetroffen', ort: 'Hamburg' }] }),
    paket({ id: 'e'.repeat(20), datum: jetzt - 74 * 3600e3, absender: 'Zalando SE', sendung: '01234567890123', stand: 'zugestellt', dienst: 'dpd',
      ereignisse: [{ zeit: zeit(74), text: 'Zugestellt', ort: 'Hamburg' }] }),
    { id: 'a'.repeat(20), datum: jetzt - 60e3, absender: 'Finanzamt Hamburg-Nord', art: 'brief', bild: true, wichtig: true, konto: 'e1', konto_name: 'Kim' },
    { id: 'b'.repeat(20), datum: jetzt - 120e3, absender: 'AOK Nordwest', art: 'brief', bild: true, konto: 'e1', konto_name: 'Kim' },
    { id: 'f'.repeat(20), datum: jetzt - 26 * 3600e3, absender: 'Stadtwerke Hamburg', art: 'brief', bild: true, konto: 'e1', konto_name: 'Kim' },
    { id: 'd'.repeat(20), datum: jetzt - 50 * 3600e3, absender: '', art: 'brief', bild: false, konto: 'e1', konto_name: 'Kim' },
  ],
};
const KONTEN = [{ id: 'e1', name: 'Kim', fehler: '', zeiten: ['02:00', '05:00'], dhl_live: true, siebzehn: true, siebzehn_rest: 187 }];

const server = http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => (body += c));
  req.on('end', () => {
    log(`${req.method} ${req.url} ${body.slice(0, 200)}`);
    const json = (o, code = 200) => { res.writeHead(code, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(o)); };
    if (req.url.startsWith('/github/releases')) {
      return json({ tag_name: 'v9.9.9', name: '9.9.9', html_url: 'https://github.com/Teyro/Paketbote/releases/tag/v9.9.9', body: '- Testversion', assets: [] });
    }
    if (req.headers.authorization !== 'Bearer ' + TOKEN) { res.writeHead(401); res.end('401: Unauthorized'); return; }
    const url = new URL(req.url, 'http://x');
    if (!url.pathname.startsWith('/api/briefankuendigung/')) { res.writeHead(404); res.end('404: Not Found'); return; }
    const p = url.pathname.slice(23);
    const d = (() => { try { return JSON.parse(body || '{}'); } catch { return {}; } })();
    if (p === 'briefe') {
      return json({ version: 4, stand: POST.stand, fehler: '', dienste: NAMEN,
        konten: KONTEN.map((x) => ({ ...x, stand: POST.stand, naechster_abruf: jetzt + 6 * 3600e3, laeuft: false })),
        briefe: POST.briefe.map((b) => ({ ...b, erledigt: POST.erledigt.has(b.id) || b.stand === 'zugestellt' })) });
    }
    if (p.startsWith('bild/')) {
      const i = POST.briefe.findIndex((b) => b.id === p.slice(5) && b.bild);
      if (i < 0) { res.writeHead(404); return res.end(); }
      res.writeHead(200, { 'Content-Type': 'image/png' });
      return res.end(umschlagPNG(480, 300, i));
    }
    if (p === 'archiv') {
      return json({ eintraege: POST.briefe.map((b) => ({ id: b.id, datum: b.datum, absender: b.absender || b.name || '', art: b.art, dienst: b.dienst || '' }))
        .concat([1, 2, 3, 4, 5, 6, 7, 8].map((n) => ({ id: 'x' + n, datum: jetzt - n * 18 * 86400e3, absender: n % 2 ? 'OTTO GmbH & Co KG' : 'Thalia Bücher GmbH', art: 'paket', dienst: n % 2 ? 'hermes' : 'dhl' }))) });
    }
    if (p === 'erledigt' && req.method === 'POST') {
      if (!POST.briefe.some((b) => b.id === d.id)) return json({ message: 'nicht gefunden' }, 404);
      if (d.erledigt) POST.erledigt.add(d.id); else POST.erledigt.delete(d.id);
      return json(d);
    }
    if (p === 'sendung' && req.method === 'POST') {
      const nr = String(d.nummer || '').toUpperCase().replace(/\s/g, '');
      const dienst = d.dienst || (/^TBA/.test(nr) ? 'amazon' : /^(00\d{18}|JJD)/.test(nr) ? 'dhl' : /^1Z/.test(nr) ? 'ups' : /^H/.test(nr) ? 'hermes' : '');
      if (!nr || !NAMEN[dienst]) return json({ message: 'Paketdienst nicht erkannt' }, 400);
      // wie Integration 1.8: Stand des Geräts übernehmen (nie zurück)
      const si = d.stand_info || {};
      const stufe = { unterwegs: 1, heute: 3, abholbereit: 3, zugestellt: 4 };
      console.log('sendung', nr, si.stand || '-', (si.ereignisse || []).length);
      const da = POST.briefe.find((x) => x.sendung === nr);
      if (da) {
        if (si.stand && (stufe[si.stand] || 0) >= (stufe[da.stand] || 1)) Object.assign(da, { stand: si.stand, ereignisse: si.ereignisse || da.ereignisse });
        if (si.erledigt) POST.erledigt.add(da.id);
        return json(da);
      }
      const b = paket({ id: nr.toLowerCase().replace(/[^0-9a-f]/g, '').padEnd(20, 'a').slice(0, 20), datum: Date.now(), absender: d.name || '', sendung: nr, dienst, manuell: true,
        ...(si.stand ? { stand: si.stand, ereignisse: si.ereignisse || [] } : {}) });
      if (si.erledigt) POST.erledigt.add(b.id);
      POST.briefe.unshift(b);
      return json(b);
    }
    if (p === 'sendung/entfernen' && req.method === 'POST') {
      POST.briefe = POST.briefe.filter((b) => b.id !== d.id || !b.manuell);
      return json(d);
    }
    if (p === 'sendung/name' && req.method === 'POST') {
      const b = POST.briefe.find((x) => x.id === d.id);
      if (!b) return json({ message: 'nicht gefunden' }, 404);
      if (d.name) b.name = d.name; else delete b.name;
      return json({ id: d.id });
    }
    if (p === 'abrufen' && req.method === 'POST') { POST.abrufe++; POST.stand = Date.now(); return json({ gestartet: 1 }, 202); }
    res.writeHead(404); res.end('404');
  });
});
server.listen(PORT, process.env.HA_MOCK_HOST || '127.0.0.1', () => console.log('Briefankündigung-Nachbau auf', PORT));
