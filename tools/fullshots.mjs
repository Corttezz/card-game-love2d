// Capturas de página inteira (390 e 1440), headless, com erros de console. uso: node tools/fullshots.mjs <url> <dir> <langs>
import { chromium } from 'playwright-core';
const [, , base, out, langs = 'en,pt'] = process.argv;
const b = await chromium.launch({ executablePath: 'C:/Users/corte/AppData/Local/ms-playwright/chromium_headless_shell-1254/chrome-headless-shell-win64/chrome-headless-shell.exe' });
for (const lang of langs.split(',')) for (const [n, w, h, m] of [['390', 390, 844, true], ['1440', 1440, 900, false]]) {
  const ctx = await b.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: m ? 2 : 1, isMobile: m, hasTouch: m });
  const p = await ctx.newPage(); const errs = [];
  p.on('console', (x) => { if (x.type() === 'error') errs.push(x.text()); }); p.on('pageerror', (e) => errs.push(e.message));
  await p.goto(base + (lang === 'en' ? '/' : `/${lang}/`), { waitUntil: 'networkidle' });
  await p.evaluate(async () => { for (let y = 0; y < document.body.scrollHeight; y += 400) { scrollTo(0, y); await new Promise((r) => setTimeout(r, 60)); } scrollTo(0, 0); });
  await p.waitForTimeout(1200);
  const over = await p.evaluate(() => document.documentElement.scrollWidth - innerWidth);
  await p.screenshot({ path: `${out}/${lang}_${n}_full.png`, fullPage: true });
  console.log(lang, n, 'erros:', errs.length, errs.slice(0, 3).join(' | '), 'overflow:', over);
  await ctx.close();
}
await b.close();
