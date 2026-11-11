// Teste de ponta a ponta da v2 (headless): idiomas, trailer ao clicar, "Me avise" (com saída do e-mail de teste), privacidade, 404.
// uso: node tools/e2e.mjs [base]
import { chromium } from 'playwright-core';
const base = process.argv[2] || 'https://runemoire.com';
const b = await chromium.launch({ executablePath: 'C:/Users/corte/AppData/Local/ms-playwright/chromium_headless_shell-1254/chrome-headless-shell-win64/chrome-headless-shell.exe' });
const res = []; const errs = [];
const ok = (n, c, x = '') => { res.push(!!c); console.log(c ? 'PASS' : 'FAIL', n, x); };
const page = async (p, w = 390) => { const ctx = await b.newContext({ viewport: { width: w, height: 844 }, isMobile: w < 500, hasTouch: w < 500 }); const pg = await ctx.newPage(); pg.on('console', (m) => { if (m.type() === 'error' && !p.includes('nada')) errs.push(p + ' ' + m.text()); }); pg.on('pageerror', (e) => errs.push(p + ' ' + e.message)); await pg.goto(base + p, { waitUntil: 'networkidle' }); return { ctx, pg }; };
for (const [p, word] of [['/', 'Notify me at launch'], ['/pt/', 'Me avise no lançamento'], ['/es/', 'Avísame'], ['/fr/', 'Prévenez-moi'], ['/de/', 'Benachrichtige']]) {
  const { ctx, pg } = await page(p);
  ok(`página ${p}`, (await pg.textContent('body')).includes(word) && (await pg.$$('.shots img')).length === 3 && (await pg.evaluate(() => document.documentElement.scrollWidth <= innerWidth)), word);
  await ctx.close();
}
{
  const { ctx, pg } = await page('/', 1440);
  await pg.click('.trailer .play'); await pg.waitForTimeout(800);
  ok('trailer só carrega ao clicar', !!(await pg.$('.trailer video')));
  await pg.fill('#email', 'nao-e-email'); await pg.click('form.notify button');
  ok('e-mail inválido avisa', /look right|não parece/i.test(await pg.textContent('form.notify .msg')));
  await ctx.close();
}
{
  const { ctx, pg } = await page('/pt/');
  await pg.fill('#email', 'teste-v2@example.com'); await pg.click('form.notify button');
  await pg.waitForSelector('form.notify .msg a', { timeout: 10000 });
  const href = await pg.getAttribute('form.notify .msg a', 'href');
  ok('Me avise grava e devolve link de saída', /\/pt\/unsubscribe\/\?t=/.test(href));
  await pg.goto(base + href, { waitUntil: 'networkidle' }); await pg.click('#unsub button'); await pg.waitForTimeout(1500);
  ok('saída apaga o e-mail de teste', /apagado/i.test(await pg.textContent('#unsub .msg')));
  await ctx.close();
}
for (const [p, word] of [['/pt/privacy/', 'Privacidade'], ['/de/nada', '']]) { const { ctx, pg } = await page(p); ok(`página ${p}`, word ? (await pg.textContent('body')).includes(word) : (await pg.textContent('h1')).length > 3); await ctx.close(); }
ok('sem erros de console', errs.length === 0, errs.slice(0, 3).join(' | '));
await b.close();
const f = res.filter((x) => !x).length; console.log(`\n${res.length - f}/${res.length} PASS`); process.exit(f ? 1 : 0);
