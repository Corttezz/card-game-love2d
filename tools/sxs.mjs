// Capturas do SITE nos mesmos passos da abertura capturada no jogo (tools/screenshot_boot_full.lua do jogo),
// avançando o porte em passos fixos de 1/60 s (?manual), e as folhas lado a lado jogo x site.
// uso: node tools/sxs.mjs <base> <outdir> [langs=pt,en] [sizes=1440x900,390x844]
import { chromium } from 'playwright-core';
import fs from 'fs';
const [, , base, out, langs = 'pt,en', sizesArg = '1440x900,390x844'] = process.argv;
fs.mkdirSync(out, { recursive: true });
const b = await chromium.launch({ executablePath: 'C:/Users/corte/AppData/Local/ms-playwright/chromium_headless_shell-1254/chrome-headless-shell-win64/chrome-headless-shell.exe', args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const report = [];
for (const lang of langs.split(',')) for (const size of sizesArg.split(',')) {
  const [w, h] = size.split('x').map(Number);
  const ctx = await b.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
  const p = await ctx.newPage(); const errs = [];
  p.on('console', (x) => { if (x.type() === 'error' && !/api\/view/.test(x.text())) errs.push(x.text()); if (x.type() === 'warning' && /runemoire/.test(x.text())) errs.push(x.text()); });
  p.on('pageerror', (e) => errs.push(e.message));
  await p.goto(base + (lang === 'en' ? '/' : `/${lang}/`) + '?manual', { waitUntil: 'networkidle' });
  await p.evaluate(() => window.__rmReady());
  const loc = lang === 'pt' ? 'pt_BR' : lang;
  const shot = async (name) => { await p.evaluate(() => window.__rm.draw()); await p.waitForTimeout(60); await p.screenshot({ path: `${out}/${loc}_${w}x${h}_${name}.png` }); };
  const run = (secs) => p.evaluate((n) => { for (let i = 0; i < n; i++) window.__rm.step(1 / 60); }, Math.round(secs * 60));
  const until = (fn, max = 60) => p.evaluate(([src, max]) => { const f = new Function('g', 'return ' + src); let n = 0; while (!f(window.__rm) && n < max * 60) { window.__rm.step(1 / 60); n++; } return n / 60; }, [fn, max]);
  await run(1.0); await shot('b0_off');
  await p.evaluate(() => window.__rmPress());
  await run(0.33); await shot('b1_insert_a');
  await run(0.44); await shot('b1_insert_b');
  await until("g.intro.phase === 'power'");
  await run(0.06); await shot('b2_tube_05');
  await run(0.24); await shot('b2_tube_25');
  await run(0.30); await shot('b2_tube_50');
  await until("g.intro.phase === 'hold'"); await shot('b4_page_typed');
  await until("g.intro.phase === 'flash'"); await run(0.05); await shot('b2_flash');
  await until("g.intro.phase === 'dive'"); await run(0.25); await shot('b5_dive_25');
  await run(0.25); await shot('b5_dive_50'); await run(0.30); await shot('b5_dive_80');
  await until("g.mode === 'boot'");
  await run(5 / 60); await shot('b2_power_05');
  await run(13 / 60); await shot('b3_loading');
  await run(4 / 60); await shot('b2_power_20');
  await run(27 / 60); await shot('b2_power_45');
  await until("g.boot.phase === 'splash'");
  await run(2.0); await shot('b3_splash_20'); await run(1.5); await shot('b3_splash_35'); await run(1.5); await shot('b3_splash_50');
  await until("g.mode === 'menu'");
  const st = async (t, name) => { await p.evaluate((t) => { while (window.__rm.brand.clock < t - 1e-6) window.__rm.step(1 / 60); }, t); await shot(name); };
  await st(1.4, 'b3_sting_14'); await st(2.2, 'b3_sting_22'); await st(2.6, 'b3_sting_26'); await st(2.8, 'b3_sting_28');
  await st(3.2, 'b4_sting_32'); await st(3.8, 'b4_sting_38');
  await until('!g.menu.isIntroPlaying()'); await run(1.0); await shot('b6_menu');
  report.push(`${loc} ${w}x${h} erros:${errs.length} ${errs.slice(0, 4).join(' | ')}`);
  await ctx.close();
}
await b.close();
console.log(report.join('\n'));
