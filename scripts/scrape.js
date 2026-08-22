// scripts/scrape.js
//
// Visita apiApp2.php con un navegador real (Puppeteer/Chromium) para
// esquivar el WAF (SafeLine) del servidor de INIFAP, que bloquea
// cualquier cliente HTTP que no tenga huella de navegador real
// (curl, apps móviles, etc. dan 403; un navegador de verdad da 200).
//
// Corre desde GitHub Actions (ver .github/workflows/scrape-inifap.yml),
// no desde el celular del usuario. Trae lo que usa la pantalla
// principal de la app: reportes (r=1,3,4) + tiempo real (r=5) de
// cada estación.
const fs = require('fs');
const path = require('path');
const puppeteer = require('puppeteer');

const BASE = 'https://zacatecas.inifap.gob.mx/apiApp2.php';
const OUT_DIR = path.join(__dirname, '..', 'data');
const OUT_FILE = path.join(OUT_DIR, 'latest.json');

// Mismo listado que lib/data/Stations.dart (mantener sincronizado si
// agregan/quitan estaciones ahí).
const STATION_IDS = [
  18851, 26684, 18786, 26766, 18802, 18836, 18664, 18806, 18882, 15922,
  50060, 18798, 18682, 86031, 18663, 18849, 15951, 15933, 26767, 18791,
  26779, 18679, 18829, 26786, 18796, 18782, 18777, 18670, 18879, 26775,
  15930, 18779, 18837, 15960, 26772, 18842, 18680,
];

function todayParts() {
  const now = new Date();
  const dd = String(now.getDate()).padStart(2, '0');
  const mm = String(now.getMonth() + 1).padStart(2, '0');
  const yyyy = String(now.getFullYear());
  return { dd, mm, yyyy };
}

async function fetchJson(page, url) {
  const response = await page.goto(url, {
    waitUntil: 'domcontentloaded',
    timeout: 30000,
  });
  if (!response || response.status() !== 200) {
    throw new Error(`HTTP ${response ? response.status() : 'sin respuesta'} en ${url}`);
  }
  const bodyText = await page.evaluate(() => document.body.innerText);
  return JSON.parse(bodyText);
}

async function main() {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });

  try {
    const page = await browser.newPage();
    const { dd, mm, yyyy } = todayParts();

    console.log('→ Reportes r=1,3,4...');
    const r1 = await fetchJson(page, `${BASE}?r=1`);
    const r3 = await fetchJson(page, `${BASE}?r=3`);
    const r4 = await fetchJson(page, `${BASE}?r=4`);

    console.log(`→ Tiempo real (r=5) de ${STATION_IDS.length} estaciones...`);
    const realtime = {};
    for (const idEst of STATION_IDS) {
      const url = `${BASE}?r=5&day=${dd}&month=${mm}&year=${yyyy}&id_est_given=${idEst}`;
      try {
        realtime[String(idEst)] = await fetchJson(page, url);
      } catch (err) {
        console.warn(`  ⚠️ estación ${idEst} falló: ${err.message}`);
        // seguimos con las demás, igual que hace la app
      }
    }

    const out = {
      fetched_at: new Date().toISOString(),
      reports: { r1, r3, r4 },
      realtime,
    };

    fs.mkdirSync(OUT_DIR, { recursive: true });
    fs.writeFileSync(OUT_FILE, JSON.stringify(out, null, 2));

    const okCount = Object.keys(realtime).length;
    console.log(`✅ Guardado ${OUT_FILE} (reportes ok, ${okCount}/${STATION_IDS.length} estaciones con tiempo real).`);
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error('❌ scrape.js falló:', err);
  process.exit(1);
});
