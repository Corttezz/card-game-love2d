// Teste da origem da visita (padrão de UTM): captura na chegada, primeira origem vence, cadastro grava no D1,
// saída da lista apaga e não sobra linha de teste; links internos sem UTM. O D1 é lido pelo wrangler (conta do deploy).
// uso: node tools/utm_e2e.mjs [base]
import { chromium } from 'playwright-core';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
const base = process.argv[2] || 'https://runemoire-site-v2.danielcortezdev.workers.dev';
const envFile = process.env.CF_ENV_FILE || os.homedir() + '/.config/iqnorth/cloudflare.env';
const env = { ...process.env };
for (const l of fs.readFileSync(envFile, 'utf8').split(/\r?\n/)) { const m = l.match(/^\s*(?:export\s+)?([A-Z0-9_]+)=(.*)$/); if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, ''); }
const d1 = (sql) => JSON.parse(execFileSync('npx', ['wrangler', 'd1', 'execute', 'runemoire-site', '--remote', '--json', '--command', '"' + sql + '"'], { env, shell: true, encoding: 'utf8' }))[0].results;
const b = await chromium.launch({ executablePath: 'C:/Users/corte/AppData/Local/ms-playwright/chromium_headless_shell-1254/chrome-headless-shell-win64/chrome-headless-shell.exe', args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const res = [];
const ok = (n, c, x = '') => { res.push(!!c); console.log(c ? 'PASS' : 'FAIL', n, x); };
const MAIL = 'teste-utm@example.com';
const U = { utm_source: 'instagram', utm_medium: 'social', utm_campaign: 'runemoire_teste_20261114', utm_content: 'post', utm_term: 'deckbuilder', fbclid: 'IwAR0teste_123-abc' };
d1(`DELETE FROM notify WHERE email = '${MAIL}'`);
const ctx = await b.newContext({ viewport: { width: 1440, height: 900 } });
const pg = await ctx.newPage();
const stored = () => pg.evaluate(() => JSON.parse(localStorage.getItem('rm_utm') || 'null'));
await pg.goto(base + '/pt/?' + new URLSearchParams(U), { waitUntil: 'networkidle' }); await pg.waitForTimeout(500);
const s1 = await stored();
ok('chegada com UTM: utm_* e fbclid guardados', s1 && Object.keys(U).every((k) => s1[k] === U[k]), JSON.stringify(s1));
await pg.goto(base + '/pt/blog/', { waitUntil: 'networkidle' });
await pg.goto(base + '/pt/', { waitUntil: 'networkidle' });
ok('segunda visita sem UTM mantém a primeira', JSON.stringify(await stored()) === JSON.stringify(s1));
await pg.goto(base + '/pt/?utm_source=reddit&utm_medium=community&utm_campaign=runemoire_outra_20261114', { waitUntil: 'networkidle' });
ok('visita com outra UTM não sobrescreve (primeira vence)', JSON.stringify(await stored()) === JSON.stringify(s1));
// links internos: nenhum leva UTM
const pages = ['/', '/pt/', '/pt/blog/', '/pt/privacy/', '/de/privacy/', '/blog/'];
let bad = [];
for (const p of pages) {
  await pg.goto(base + p, { waitUntil: 'domcontentloaded' });
  const hs = await pg.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => a.href).filter((h) => new URL(h, location.href).origin === location.origin));
  const first = await pg.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => a.getAttribute('href')).find((h) => /\/blog\/[a-z0-9-]+\/?$/.test(h)) || null);
  if (first && p.endsWith('blog/')) { await pg.goto(new URL(first, base + p).href, { waitUntil: 'domcontentloaded' }); hs.push(...await pg.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => a.href))); }
  bad.push(...hs.filter((h) => /[?&](utm_|fbclid)/i.test(h)).map((h) => p + ' -> ' + h));
}
ok('links internos sem UTM (home, blog, post, privacidade, rodapé)', bad.length === 0, bad.slice(0, 5).join(' | '));
// cadastro com a origem guardada
await pg.goto(base + '/pt/', { waitUntil: 'networkidle' }); await pg.waitForTimeout(500);
if (await pg.isVisible('#screenhit')) { await pg.click('#screenhit'); for (let i = 0; i < 10 && !(await pg.evaluate(() => document.documentElement.classList.contains('in-menu'))); i++) { await pg.waitForTimeout(400); await pg.keyboard.press('Space'); } }
await pg.click('.menu a[data-open="achievements"]', { force: true });
const sent = pg.waitForRequest((r) => r.url().endsWith('/api/notify'));
await pg.fill('#email', MAIL); await pg.click('#achievements form button[type=submit]');
const body = JSON.parse((await sent).postData() || '{}');
ok('cadastro envia a origem guardada', body.utm && body.utm.utm_campaign === U.utm_campaign);
await pg.waitForSelector('#achievements .msg a', { timeout: 10000 }).catch(() => {});
const href = await pg.getAttribute('#achievements .msg a', 'href').catch(() => null);
const row = d1(`SELECT variant, source, utm_source, utm_medium, utm_campaign, utm_content, utm_term, fbclid FROM notify WHERE email = '${MAIL}'`)[0];
ok('D1 grava utm_* e fbclid no cadastro', row && Object.keys(U).every((k) => row[k] === U[k]), JSON.stringify(row));
ok('variant e source seguem gravados', row && row.variant === 'v3b' && row.source === 'achievements');
if (href) { await pg.goto(base + href, { waitUntil: 'networkidle' }); await pg.click('#unsub button'); await pg.waitForTimeout(1500); }
ok('saída da lista apaga a linha (e a origem junto)', d1(`SELECT COUNT(*) AS n FROM notify WHERE email = '${MAIL}'`)[0].n === 0);
ok('0 linhas de teste no D1', d1(`SELECT COUNT(*) AS n FROM notify WHERE email LIKE '%@example.com'`)[0].n === 0);
// sem UTM na chegada: nada guardado, cadastro grava null
const c2 = await b.newContext(); const p2 = await c2.newPage();
await p2.goto(base + '/pt/', { waitUntil: 'networkidle' });
ok('chegada sem UTM não guarda nada', (await p2.evaluate(() => localStorage.getItem('rm_utm'))) === null);
await c2.close();
// valor fora do padrão não entra no D1 (o Worker limpa)
const r = await (await fetch(base + '/api/notify', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: MAIL, lang: 'pt', utm: { utm_source: '<script>', utm_medium: 'x'.repeat(200), utm_campaign: 'ok_1' } }) })).json();
const row2 = d1(`SELECT utm_source, utm_medium, utm_campaign FROM notify WHERE email = '${MAIL}'`)[0];
ok('Worker descarta valor inválido', row2 && row2.utm_source === null && row2.utm_medium === null && row2.utm_campaign === 'ok_1', JSON.stringify(row2));
if (r.token) await fetch(base + '/api/unsubscribe', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ token: r.token }) });
ok('0 linhas de teste no D1 no fim', d1(`SELECT COUNT(*) AS n FROM notify WHERE email LIKE '%@example.com'`)[0].n === 0);
await b.close();
const f = res.filter((x) => !x).length;
console.log(`${res.length - f}/${res.length} PASS`); process.exit(f ? 1 : 0);
