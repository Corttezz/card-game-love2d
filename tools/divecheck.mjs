// Confere o mergulho (quadros no meio da animação), a folga do menu sobre o livro e o painel JOGAR, headless.
// uso: node tools/divecheck.mjs <base> <dir> [sizes=390x844,1440x900,844x390]
import { chromium } from 'playwright-core';
import fs from 'fs';
const [, , base, out, sizesArg = '390x844,1440x900,844x390'] = process.argv;
fs.mkdirSync(out, { recursive: true });
const b = await chromium.launch({ executablePath: 'C:/Users/corte/AppData/Local/ms-playwright/chromium_headless_shell-1254/chrome-headless-shell-win64/chrome-headless-shell.exe' });
for (const size of sizesArg.split(',')) {
  const [w, h] = size.split('x').map(Number); const m = w < 600 || h < 600;
  const ctx = await b.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: m ? 3 : 1, isMobile: m, hasTouch: m });
  const p = await ctx.newPage();
  await p.goto(base + '/pt/', { waitUntil: 'networkidle' }); await p.waitForTimeout(1800);
  await p.click('#screenhit');
  for (const t of [120, 300, 500]) { await p.waitForTimeout(t === 120 ? 120 : t === 300 ? 180 : 200); await p.screenshot({ path: `${out}/dive${t}_${size}.png` }); }
  await p.waitForTimeout(900);
  const gap = await p.evaluate(() => { const r = document.querySelector('.menu').getBoundingClientRect(); return { menuBottom: Math.round(r.bottom), menuTop: Math.round(r.top), varL: getComputedStyle(document.getElementById('tv')).getPropertyValue('--menu-top-l') }; });
  await p.screenshot({ path: `${out}/full_${size}.png` });
  await p.click('.menu a[data-open="play"]'); await p.waitForTimeout(500);
  await p.screenshot({ path: `${out}/play_${size}.png` });
  console.log(size, JSON.stringify(gap));
  await ctx.close();
}
await b.close();
