// Grava a abertura do SITE quadro a quadro (?manual, passos de 1/60 s, 30 fps), do computador desligado até 1 s de menu parado,
// para comparar com game_intro_pt_1440.mp4 (gravado do jogo do mesmo jeito). uso: node tools/rec.mjs <base> <dir> [lang=pt] [WxH=1440x900]
import { chromium } from 'playwright-core';
import fs from 'fs';
const [, , base, out, lang = 'pt', size = '1440x900'] = process.argv;
const [w, h] = size.split('x').map(Number);
fs.mkdirSync(out, { recursive: true });
const b = await chromium.launch({ executablePath: 'C:/Users/corte/AppData/Local/ms-playwright/chromium_headless_shell-1254/chrome-headless-shell-win64/chrome-headless-shell.exe', args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const p = await (await b.newContext({ viewport: { width: w, height: h } })).newPage();
await p.goto(base + (lang === 'en' ? '/' : `/${lang}/`) + '?manual', { waitUntil: 'networkidle' });
await p.evaluate(() => window.__rmReady());
let n = 0, idle = -1;
const frame = async () => { await p.evaluate(() => window.__rm.draw()); await p.screenshot({ path: `${out}/${String(++n).padStart(5, '0')}.png` }); };
const adv = () => p.evaluate(() => { window.__rm.step(1 / 60); window.__rm.step(1 / 60); return window.__rm.mode === 'menu' && !window.__rm.menu.isIntroPlaying(); });
await p.evaluate(() => { for (let i = 0; i < 60; i++) window.__rm.step(1 / 60); });
for (let i = 0; i < 15; i++) { await frame(); await adv(); }
await p.evaluate(() => window.__rmPress());
for (let i = 0; i < 2000; i++) {
  await frame();
  const done = await adv();
  if (done && idle < 0) idle = n;
  if (idle > 0 && n - idle >= 30) break;
}
await b.close();
console.log('quadros', n);
