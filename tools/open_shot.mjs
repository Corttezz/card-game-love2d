// Captura da abertura (tomo) e do 404, sem janela.
import { chromium } from 'playwright-core';
const [, , base = 'http://127.0.0.1:8788', out = 'tools/out/shots'] = process.argv;
const b = await chromium.launch({ executablePath: 'C:/Users/corte/AppData/Local/ms-playwright/chromium_headless_shell-1254/chrome-headless-shell-win64/chrome-headless-shell.exe' });
for (const [n, w, h, m] of [['desktop', 1440, 900, false], ['mobile', 390, 844, true]]) {
  const ctx = await b.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: m ? 3 : 1, isMobile: m });
  const p = await ctx.newPage();
  await p.goto(base + '/', { waitUntil: 'networkidle' }); await p.waitForTimeout(600);
  await p.screenshot({ path: `${out}/${n}_opening.png` });
  await p.click('#open-silent'); await p.waitForTimeout(600);
  await p.screenshot({ path: `${out}/${n}_opening_open.png` });
  await p.goto(base + '/nao-existe', { waitUntil: 'networkidle' });
  await p.screenshot({ path: `${out}/${n}_404.png` });
  await ctx.close();
}
await b.close();
