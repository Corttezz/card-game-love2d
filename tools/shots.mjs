// Capturas headless (Chromium do Playwright, sem janela) por seção, tema e largura; registra erros de console.
// uso: node tools/shots.mjs <base_url> <saida_dir> [temas=fields,abyss,frost] [lang=/] [secoes=all]
import { chromium } from 'playwright-core';
import fs from 'fs';

const [, , base = 'http://127.0.0.1:8788', out = 'tools/out/shots', themesArg = 'fields,abyss,frost', langArg = 'en', secArg = 'all'] = process.argv;
const lang = langArg === 'en' ? '/' : '/' + langArg + '/';
const EXE = process.env.CHROME || 'C:/Users/corte/AppData/Local/ms-playwright/chromium_headless_shell-1254/chrome-headless-shell-win64/chrome-headless-shell.exe';
const SECTIONS = ['top', 'intro', 'trailers', 'play', 'classes', 'bestiary', 'cards', 'beyond', 'gallery', 'faq', 'press', 'final'];
const secs = secArg === 'all' ? SECTIONS : secArg.split(',');
const themes = themesArg.split(',');
const VIEWS = [{ n: 'desktop', w: 1440, h: 900, m: false }, { n: 'mobile', w: 390, h: 844, m: true }];
fs.mkdirSync(out, { recursive: true });
const b = await chromium.launch({ executablePath: EXE, headless: true });
const report = [];
for (const v of VIEWS) {
  for (const th of themes) {
    const ctx = await b.newContext({ viewport: { width: v.w, height: v.h }, deviceScaleFactor: v.m ? 3 : 1, isMobile: v.m, hasTouch: v.m, reducedMotion: 'no-preference' });
    await ctx.addInitScript((t) => { localStorage.setItem('rm.opened', '1'); localStorage.setItem('rm.biome', t); localStorage.setItem('rm.langhint', '0'); sessionStorage.setItem('rm.viewed', '1'); }, th);
    const p = await ctx.newPage();
    const errs = [];
    p.on('console', (x) => { if (x.type() === 'error') errs.push(x.text()); });
    p.on('pageerror', (e) => errs.push('pageerror: ' + e.message));
    p.on('requestfailed', (r) => errs.push('reqfail: ' + r.url()));
    p.on('response', (r) => { if (r.status() >= 400) errs.push(`${r.status()} ${r.url()}`); });
    await p.goto(base + lang, { waitUntil: 'networkidle', timeout: 60000 });
    for (const s of secs) {
      await p.evaluate((id) => { const el = document.getElementById(id); if (el) { const y = el.getBoundingClientRect().top + window.scrollY - (id === 'top' ? 0 : 56); window.scrollTo({ top: y, behavior: 'instant' }); } }, s);
      await p.waitForTimeout(900);
      await p.screenshot({ path: `${out}/${v.n}_${th}_${s}.png` });
    }
    report.push({ view: v.n, theme: th, errors: errs });
    await ctx.close();
  }
}
await b.close();
fs.writeFileSync(`${out}/report.json`, JSON.stringify(report, null, 1));
for (const r of report) console.log(r.view, r.theme, 'erros:', r.errors.length, r.errors.slice(0, 6).join(' | '));
