// Capturas de cada estado do site (v3 com o computador), headless, nos tamanhos e idiomas pedidos.
// Estados: mesa com a tela ligada, mergulho (meio), tela cheia, cada painel, conquista com toast, carta virada, sair (TV desliga) e mesa apagada.
// uso: node tools/states.mjs <base> <dir> [langs=en,pt] [notify=0|1] [sizes=1440x900,390x844]
import { chromium } from 'playwright-core';
import fs from 'fs';
const [, , base, out, langs = 'en,pt', doNotify = '0', sizesArg = '1440x900,390x844'] = process.argv;
fs.mkdirSync(out, { recursive: true });
const b = await chromium.launch({ executablePath: 'C:/Users/corte/AppData/Local/ms-playwright/chromium_headless_shell-1254/chrome-headless-shell-win64/chrome-headless-shell.exe' });
const report = [];
for (const lang of langs.split(',')) for (const size of sizesArg.split(',')) {
  const [w, h] = size.split('x').map(Number); const m = w < 600 || h < 600;
  const n = `${w}x${h}`;
  const ctx = await b.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: m ? 3 : 1, isMobile: m, hasTouch: m });
  const p = await ctx.newPage(); const errs = [];
  p.on('console', (x) => { if (x.type() === 'error' && !/api\/view/.test(x.text())) errs.push(x.text()); }); p.on('pageerror', (e) => errs.push(e.message));
  const url = base + (lang === 'en' ? '/' : `/${lang}/`);
  const shot = async (name, wait = 700) => { await p.waitForTimeout(wait); await p.screenshot({ path: `${out}/${lang}_${n}_${name}.png` }); };
  await p.goto(url, { waitUntil: 'networkidle' });
  await shot('desk', 1800);
  await p.click('#screenhit'); await shot('dive', 380); await shot('scene', 1200);
  const over = await p.evaluate(() => [document.documentElement.scrollWidth - innerWidth, document.documentElement.scrollHeight - innerHeight]);
  for (const id of ['play', 'collection', 'achievements', 'settings']) {
    await p.click(`.menu a[data-open="${id}"]`); await shot(id);
    if (id === 'achievements' && doNotify === '1') {
      await p.fill('#email', `estado-${lang}-${n}@example.com`); await p.click('#achievements form button[type=submit]');
      await p.waitForSelector('#toast.in', { timeout: 8000 }).catch(() => errs.push('toast não apareceu'));
      await shot('achievements_toast');
    }
    await p.keyboard.press('Escape'); await p.waitForTimeout(300);
  }
  if (await p.isVisible('.hang.left')) { await p.click('.hang.left', { force: true }); await shot('flipped', 900); await p.click('.hang.left', { force: true }); }
  await p.click('.menu a[data-open="quit"]'); await shot('quit', 260); await shot('desk_off', 900);
  report.push(`${lang} ${n} erros:${errs.length} ${errs.slice(0, 3).join(' | ')} overflow:${over}`);
  await ctx.close();
}
await b.close();
console.log(report.join('\n'));
