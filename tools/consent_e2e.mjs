// Teste do aceite do Clarity (prévia com ?cc=): banner, cookies, pedidos ao clarity.ms, teclado, intro "clique na tela".
// uso: node tools/consent_e2e.mjs [base]
import { chromium } from 'playwright-core';
const base = process.argv[2] || 'https://runemoire-site-v2.danielcortezdev.workers.dev';
const b = await chromium.launch({ executablePath: 'C:/Users/corte/AppData/Local/ms-playwright/chromium_headless_shell-1254/chrome-headless-shell-win64/chrome-headless-shell.exe', args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const res = [];
const ok = (n, c, x = '') => { res.push(!!c); console.log(c ? 'PASS' : 'FAIL', n, x); };
const run = async (cc, path, w, h, choice) => {
  const m = w < 600;
  const ctx = await b.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: m ? 3 : 1, isMobile: m, hasTouch: m });
  await ctx.addInitScript(() => { Object.defineProperty(navigator, 'webdriver', { get: () => false }); });
  const pg = await ctx.newPage();
  const cl = []; pg.on('request', (r) => { if (/clarity\.ms/.test(r.url())) cl.push(r.url()); });
  await pg.goto(base + path + '?cc=' + cc, { waitUntil: 'networkidle' }); await pg.waitForTimeout(1200);
  const tag = `${cc} ${path} ${w}x${h}`;
  const box = await pg.$('.consent');
  const ck = async () => (await ctx.cookies()).filter((c) => /^_cl/.test(c.name)).length;
  if (cc === 'BR') {
    ok(tag + ': sem banner', !box);
    await pg.waitForTimeout(1500);
    ok(tag + ': Clarity carrega', cl.length > 0, `pedidos=${cl.length}`);
  } else {
    ok(tag + ': banner aparece', !!box);
    ok(tag + ': 0 cookies e 0 pedidos antes', (await ck()) === 0 && cl.length === 0, `cookies=${await ck()} pedidos=${cl.length}`);
    const r = await pg.evaluate(() => {
      const a = document.querySelector('.consent').getBoundingClientRect(), h = document.querySelector('#hint');
      const t = h ? h.getBoundingClientRect() : null;
      const over = t && t.height > 0 && getComputedStyle(h).display !== 'none' && !(a.bottom <= t.top || a.top >= t.bottom || a.right <= t.left || a.left >= t.right);
      const d = document.querySelector('.consent');
      return { over: !!over, describedOk: !!(d.getAttribute('aria-describedby') && document.getElementById(d.getAttribute('aria-describedby'))), role: d.getAttribute('role'), label: d.getAttribute('aria-label'), desc: d.getAttribute('aria-describedby'), top: Math.round(a.top), bottom: Math.round(a.bottom) };
    });
    ok(tag + ': banner não cobre a dica da intro', !r.over, JSON.stringify(r));
    ok(tag + ': role, nome e descrição acessíveis', r.role && r.label && r.describedOk);
    if (await pg.isVisible('#screenhit')) {
      await pg.click('#screenhit');
      await pg.waitForTimeout(800);
      ok(tag + ': clicar na tela com o banner aberto roda a intro', await pg.evaluate(() => window.__rm && window.__rm.intro && window.__rm.intro.phase !== 'off'));
      ok(tag + ': banner segue aberto (clique na tela não decide)', !!(await pg.$('.consent')));
      for (let i = 0; i < 10 && !(await pg.evaluate(() => document.documentElement.classList.contains('in-menu'))); i++) { await pg.waitForTimeout(400); await pg.keyboard.press('Space'); }
      await pg.waitForTimeout(600);
      const hid = await pg.evaluate(() => {
        window.__cb = document.querySelector('.consent').getBoundingClientRect().bottom;
        const a = document.querySelector('.consent').getBoundingClientRect();
        return [...document.querySelectorAll('#title button, #title a')].filter((e) => { const r = e.getBoundingClientRect(); return r.width > 0 && r.height > 0 && !(a.bottom <= r.top || a.top >= r.bottom || a.right <= r.left || a.left >= r.right); }).map((e) => e.textContent.trim().slice(0, 20));
      });
      ok(tag + ': no menu, o banner não cobre botões', hid.length === 0, JSON.stringify(hid));
    }
    let f = null;
    for (let i = 0; i < 25 && !f; i++) { await pg.keyboard.press('Tab'); f = await pg.evaluate(() => (document.activeElement && document.activeElement.closest('.consent')) ? document.activeElement.textContent : null); }
    ok(tag + ': alcançável pelo Tab', !!f, String(f));
    await pg.focus(choice === 'yes' ? '.consent-yes' : '.consent-no'); await pg.keyboard.press('Enter');
    await pg.waitForTimeout(3000);
    ok(tag + `: ${choice} pelo teclado fecha o banner`, !(await pg.$('.consent')));
    if (choice === 'yes') ok(tag + ': depois de aceitar o Clarity carrega', cl.length > 0, `pedidos=${cl.length} cookies=${await ck()}`);
    else ok(tag + ': depois de recusar, 0 pedidos e 0 cookies', cl.length === 0 && (await ck()) === 0, `pedidos=${cl.length} cookies=${await ck()}`);
    await pg.reload({ waitUntil: 'networkidle' }); await pg.waitForTimeout(800);
    ok(tag + ': escolha lembrada (sem banner ao voltar)', !(await pg.$('.consent')));
  }
  await ctx.close();
};
await run('DE', '/de/', 1440, 900, 'yes');
await run('DE', '/de/', 390, 844, 'no');
await run('FR', '/fr/', 1280, 720, 'no');
await run('GB', '/', 1440, 900, 'yes');
await run('BR', '/pt/', 1440, 900);
await b.close();
const f = res.filter((x) => !x).length;
console.log(`${res.length - f}/${res.length} PASS`); process.exit(f ? 1 : 0);
