// scripts/scrape.js
//
// Visita apiApp2.php con un navegador real (Puppeteer/Chromium) para
// esquivar el WAF (SafeLine) del servidor de INIFAP, que bloquea
// cualquier cliente HTTP que no tenga huella de navegador real
// (curl, apps móviles, etc. dan 403; un navegador de verdad da 200).
//
// Corre desde GitHub Actions (ver .github/workflows/scrape-inifap.yml),
// no desde el celular del usuario.
const fs = require('fs');
const path = require('path');
const puppeteer = require('puppeteer');

const URL = 'https://zacatecas.inifap.gob.mx/apiApp2.php?r=1';
const OUT_DIR = path.join(__dirname, '..', 'data');
const OUT_FILE = path.join(OUT_DIR, 'latest.json');

async function main() {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });

  try {
    const page = await browser.newPage();
    const response = await page.goto(URL, {
      waitUntil: 'domcontentloaded',
      timeout: 30000,
    });

    if (!response || response.status() !== 200) {
      throw new Error(`HTTP ${response ? response.status() : 'sin respuesta'} al visitar ${URL}`);
    }

    // La respuesta es JSON puro; Chrome lo muestra como texto plano en <pre>.
    const bodyText = await page.evaluate(() => document.body.innerText);
    const parsed = JSON.parse(bodyText); // valida que sí sea JSON antes de guardar

    fs.mkdirSync(OUT_DIR, { recursive: true });
    fs.writeFileSync(
      OUT_FILE,
      JSON.stringify(
        {
          fetched_at: new Date().toISOString(),
          source: URL,
          data: parsed,
        },
        null,
        2
      )
    );

    console.log(`✅ Guardado ${OUT_FILE} (${parsed.length} estaciones).`);
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error('❌ scrape.js falló:', err);
  process.exit(1);
});
