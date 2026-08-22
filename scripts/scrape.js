// scripts/scrape.js
//
// Visita apiApp2.php con un navegador real (Puppeteer/Chromium) para
// esquivar el WAF (SafeLine) del servidor de INIFAP, que bloquea
// cualquier cliente HTTP que no tenga huella de navegador real
// (curl, apps móviles, etc. dan 403; un navegador de verdad da 200).
//
// Corre desde GitHub Actions (ver .github/workflows/scrape-inifap.yml),
// no desde el celular del usuario. Trae TODO lo que usa la app:
// lista de estaciones (r=all), reportes (r=1,3,4), y por cada
// estación: tiempo real (r=5), extras del día (r=6,7,8,9) e
// histórico del mes actual (r=10).
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

    console.log('→ Lista de estaciones (r=all)...');
    let all = null;
    try {
      all = await fetchJson(page, `${BASE}?r=all`);
    } catch (err) {
      // r=all parece devolver body vacío incluso en navegador real (bug
      // del lado de INIFAP, no nuestro). La app ya sabe usar su lista
      // fija de estaciones cuando esto pasa, así que no truena el resto.
      console.warn(`  ⚠️ r=all falló, se omite del espejo: ${err.message}`);
    }

    console.log('→ Reportes r=1,3,4...');
    const r1 = await fetchJson(page, `${BASE}?r=1`);
    const r3 = await fetchJson(page, `${BASE}?r=3`);
    const r4 = await fetchJson(page, `${BASE}?r=4`);

    console.log(`→ Tiempo real, extras del día e histórico de ${STATION_IDS.length} estaciones...`);
    const realtime = {};
    const daily = {};
    const history = {};

    for (const idEst of STATION_IDS) {
      const idStr = String(idEst);

      try {
        realtime[idStr] = await fetchJson(
          page,
          `${BASE}?r=5&day=${dd}&month=${mm}&year=${yyyy}&id_est_given=${idEst}`
        );
      } catch (err) {
        console.warn(`  ⚠️ r=5 estación ${idEst} falló: ${err.message}`);
      }

      daily[idStr] = {};
      for (const r of [6, 7, 8, 9]) {
        try {
          daily[idStr][`r${r}`] = await fetchJson(
            page,
            `${BASE}?r=${r}&day=${dd}&month=${mm}&year=${yyyy}&id_est_given=${idEst}`
          );
        } catch (err) {
          console.warn(`  ⚠️ r=${r} estación ${idEst} falló: ${err.message}`);
        }
      }

      try {
        history[idStr] = await fetchJson(
          page,
          `${BASE}?r=10&month=${mm}&year=${yyyy}&id_est_given=${idEst}`
        );
      } catch (err) {
        console.warn(`  ⚠️ r=10 estación ${idEst} falló: ${err.message}`);
      }
    }

    const out = {
      fetched_at: new Date().toISOString(),
      all,
      reports: { r1, r3, r4 },
      realtime,
      daily,
      history,
    };

    fs.mkdirSync(OUT_DIR, { recursive: true });
    fs.writeFileSync(OUT_FILE, JSON.stringify(out, null, 2));

    const okCount = Object.keys(realtime).length;
    console.log(`✅ Guardado ${OUT_FILE} (${okCount}/${STATION_IDS.length} estaciones completas).`);
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error('❌ scrape.js falló:', err);
  process.exit(1);
});
