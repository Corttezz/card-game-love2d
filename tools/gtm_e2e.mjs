// Teste do Google Tag Manager + GA4 com Consent Mode v2 (prévia com ?cc=): BR carrega o contêiner e mede; DE não manda nada
// ao Google antes do "Aceitar" (0 gtm.js, 0 collect, 0 _ga) e mede depois; recusar segue sem nada. O cadastro empurra
// generate_lead com event_id (o mesmo gravado no D1) e sem e-mail. Lê o D1 pelo wrangler (conta do deploy) e apaga o teste.
// uso: node tools/gtm_e2e.mjs [base] (em runemoire.com só a parte BR: o país vem do IP e cadastro de teste sujaria o GA4)
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
const MAIL = 'teste-gtm@example.com';
const sep = (u) => (u.includes('?') ? '&' : '?');
const visit = async (cc, path) => {
  const ctx = await b.newContext({ viewport: { width: 1440, height: 900 } });
  await ctx.addInitScript(() => { Object.defineProperty(navigator, 'webdriver', { get: () => false }); });
  const pg = await ctx.newPage();
  const net = { gtm: 0, gtag: 0, collect: [], errs: [] };
  pg.on('request', (r) => {
    const u = r.url();
    if (/googletagmanager\.com\/gtm\.js/.test(u)) net.gtm++;
    if (/googletagmanager\.com\/gtag\/js/.test(u)) net.gtag++;
    if (/\/g\/collect/.test(u)) net.collect.push(u + ' ' + (r.postData() || ''));
  });
  pg.on('console', (m) => { if (m.type() === 'error' && /Content Security Policy|CSP/i.test(m.text())) net.errs.push(m.text().slice(0, 160)); });
  await pg.goto(base + path + sep(path) + 'cc=' + cc, { waitUntil: 'networkidle' });
  await pg.waitForTimeout(4000);
  const ga = async () => (await ctx.cookies()).filter((c) => /^_ga/.test(c.name)).map((c) => c.name);
  return { ctx, pg, net, ga };
};
const consentOf = (pg) => pg.evaluate(() => (window.dataLayer || []).filter((x) => x && x[0] === 'consent').map((x) => x[1] + ':' + x[2].analytics_storage));

{
  const { ctx, pg, net, ga } = await visit('BR', '/pt/');
  ok('BR: sem banner', !(await pg.$('.consent')));
  ok('BR: consent default concedido antes do contêiner', (await consentOf(pg))[0] === 'default:granted', JSON.stringify(await consentOf(pg)));
  ok('BR: gtm.js carrega', net.gtm === 1, `gtm.js=${net.gtm}`);
  ok('BR: GA4 coleta (collect)', net.collect.length > 0, `collect=${net.collect.length} gtag/js=${net.gtag} cookies=${(await ga()).join(',')}`);
  ok('BR: CSP não bloqueia nada', net.errs.length === 0, net.errs.join(' | '));
  await ctx.close();
}
const PROD = new URL(base).hostname === 'runemoire.com';
for (const choice of PROD ? [] : ['yes', 'no']) {
  const { ctx, pg, net, ga } = await visit('DE', '/de/');
  ok(`DE (${choice}): banner aparece`, !!(await pg.$('.consent')));
  ok(`DE (${choice}): consent default negado`, (await consentOf(pg))[0] === 'default:denied', JSON.stringify(await consentOf(pg)));
  ok(`DE (${choice}): antes do aceite 0 gtm.js, 0 collect, 0 _ga`, net.gtm === 0 && net.collect.length === 0 && (await ga()).length === 0, `gtm.js=${net.gtm} collect=${net.collect.length} _ga=${(await ga()).length}`);
  await pg.click(choice === 'yes' ? '.consent-yes' : '.consent-no');
  await pg.waitForTimeout(5000);
  if (choice === 'yes') {
    ok('DE (yes): update concedido', (await consentOf(pg)).includes('update:granted'), JSON.stringify(await consentOf(pg)));
    ok('DE (yes): gtm.js carrega depois do aceite', net.gtm === 1, `gtm.js=${net.gtm}`);
    ok('DE (yes): GA4 coleta e grava _ga depois do aceite', net.collect.length > 0 && (await ga()).length > 0, `collect=${net.collect.length} cookies=${(await ga()).join(',')}`);
    await pg.reload({ waitUntil: 'networkidle' }); await pg.waitForTimeout(3000);
    ok('DE (yes): na volta, já carrega concedido', (await consentOf(pg)).includes('update:granted') && net.gtm === 2);
  } else {
    ok('DE (no): recusa segue sem nada', net.gtm === 0 && net.collect.length === 0 && (await ga()).length === 0, `gtm.js=${net.gtm} collect=${net.collect.length} _ga=${(await ga()).length}`);
  }
  ok(`DE (${choice}): CSP não bloqueia nada`, net.errs.length === 0, net.errs.join(' | '));
  await ctx.close();
}
// cadastro: generate_lead sem e-mail, event_id igual ao do D1
d1(`DELETE FROM notify WHERE email = '${MAIL}'`);
for (const [path, sel] of PROD ? [] : [['/pt/?utm_source=instagram&utm_medium=social&utm_campaign=runemoire_teste_20261115', 'home'], ['/blog/', 'blog']]) {
  const { ctx, pg, net } = await visit('BR', path);
  if (sel === 'home') {
    if (await pg.isVisible('#screenhit')) { await pg.click('#screenhit'); for (let i = 0; i < 10 && !(await pg.evaluate(() => document.documentElement.classList.contains('in-menu'))); i++) { await pg.waitForTimeout(400); await pg.keyboard.press('Space'); } }
    await pg.click('.menu a[data-open="achievements"]', { force: true });
    await pg.fill('#email', MAIL); await pg.click('#achievements form button[type=submit]');
  } else {
    const post = await pg.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => a.getAttribute('href')).find((h) => /^\/blog\/[a-z0-9-]+\/$/.test(h)));
    await pg.goto(base + post + '?cc=BR', { waitUntil: 'networkidle' });
    await pg.fill('form.notify input[type=email]', MAIL); await pg.click('form.notify button[type=submit]');
  }
  await pg.waitForFunction(() => (window.dataLayer || []).some((x) => x && x.event === 'generate_lead'), null, { timeout: 10000 }).catch(() => {});
  const ev = await pg.evaluate(() => (window.dataLayer || []).find((x) => x && x.event === 'generate_lead') || null);
  const all = JSON.stringify(await pg.evaluate(() => JSON.stringify(window.dataLayer || [], (k, v) => (v instanceof Element ? undefined : v))));
  ok(`${sel}: generate_lead no dataLayer`, !!ev, JSON.stringify(ev));
  ok(`${sel}: nenhum e-mail no dataLayer`, !all.includes('@') && !all.includes(MAIL));
  ok(`${sel}: event_id é UUID`, ev && /^[0-9a-f-]{36}$/.test(ev.event_id));
  if (sel === 'home') ok('home: UTMs da primeira visita no evento', ev && ev.utm_source === 'instagram' && ev.utm_campaign === 'runemoire_teste_20261115');
  const row = d1(`SELECT event_id, source FROM notify WHERE email = '${MAIL}'`)[0];
  ok(`${sel}: o mesmo event_id gravado no D1`, row && ev && row.event_id === ev.event_id, JSON.stringify(row));
  await pg.waitForTimeout(6000);
  const hit = net.collect.find((c) => /en=generate_lead/.test(c)) || '';
  ok(`${sel}: GA4 recebeu generate_lead com o event_id`, hit && ev && hit.includes(ev.event_id), hit ? 'collect com en=generate_lead' : `collect=${net.collect.length}`);
  ok(`${sel}: collect sem e-mail`, !net.collect.some((c) => /%40|@|example\.com|teste-gtm/i.test(decodeURIComponent(c.replace(/\+/g, ' ')))));
  d1(`DELETE FROM notify WHERE email = '${MAIL}'`);
  await ctx.close();
}
ok('0 linhas de teste no D1', d1(`SELECT COUNT(*) AS n FROM notify WHERE email LIKE '%@example.com'`)[0].n === 0);
await b.close();
const f = res.filter((x) => !x).length;
console.log(`${res.length - f}/${res.length} PASS`); process.exit(f ? 1 : 0);
