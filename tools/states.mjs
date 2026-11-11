// Capturas de cada estado da tela de título (v3), headless, 1440x900 e 390x844, nos idiomas pedidos.
// uso: node tools/states.mjs <base> <dir> [langs=en,pt] [notify=0|1]
import { chromium } from 'playwright-core';
import fs from 'fs';
const [, , base, out, langs = 'en,pt', doNotify = '0'] = process.argv;
fs.mkdirSync(out, { recursive: true });
const b = await chromium.launch({ executablePath: 'C:/Users/corte/AppData/Local/ms-playwright/chromium_headless_shell-1254/chrome-headless-shell-win64/chrome-headless-shell.exe' });
const report = [];
for (const lang of langs.split(',')) for (const [n, w, h, m] of [['1440', 1440, 900, false], ['390', 390, 844, true]]) {
  const ctx = await b.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: m ? 3 : 1, isMobile: m, hasTouch: m });
  const p = await ctx.newPage(); const errs = [];
  p.on('console', (x) => { if (x.type() === 'error') errs.push(x.text()); }); p.on('pageerror', (e) => errs.push(e.message));
  const url = base + (lang === 'en' ? '/' : `/${lang}/`);
  const shot = async (name) => { await p.waitForTimeout(700); await p.screenshot({ path: `${out}/${lang}_${n}_${name}.png` }); };
  await p.goto(url, { waitUntil: 'networkidle' }); await p.waitForTimeout(1200);
  await shot('scene');
  const over = await p.evaluate(() => [document.documentElement.scrollWidth - innerWidth, document.documentElement.scrollHeight - innerHeight]);
  for (const id of ['play', 'collection', 'achievements', 'settings']) {
    await p.click(`.menu a[data-open="${id}"]`); await shot(id);
    if (id === 'achievements' && doNotify === '1') {
      await p.fill('#email', `estado-${lang}-${n}@example.com`); await p.click('form.notify button[type=submit]');
      await p.waitForSelector('#toast.in', { timeout: 8000 }).catch(() => errs.push('toast não apareceu'));
      await shot('achievements_toast');
    }
    await p.keyboard.press('Escape'); await p.waitForTimeout(300);
  }
  await p.click('.hang.left', { force: true }); await p.waitForTimeout(900); await shot('flipped');
  await p.click('.hang.left', { force: true }); await p.waitForTimeout(400);
  await p.click('.menu a[data-open="quit"]'); await p.waitForTimeout(1800); await shot('quit');
  report.push(`${lang} ${n} erros:${errs.length} ${errs.slice(0, 3).join(' | ')} overflow:${over}`);
  await ctx.close();
}
await b.close();
console.log(report.join('\n'));
