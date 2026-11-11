// Teste de ponta a ponta, headless: mesa, temas, segredos, Konami, embaralhar, "Me avise" (com limpeza), idiomas.
// uso: node tools/e2e.mjs [base=https://runemoire.com]
import { chromium } from 'playwright-core';

const base = process.argv[2] || 'https://runemoire.com';
const EXE = 'C:/Users/corte/AppData/Local/ms-playwright/chromium_headless_shell-1254/chrome-headless-shell-win64/chrome-headless-shell.exe';
const b = await chromium.launch({ executablePath: EXE });
const results = [];
const ok = (name, cond, extra = '') => { results.push({ name, pass: !!cond, extra }); console.log(cond ? 'PASS' : 'FAIL', name, extra); };
const errs = [];

async function page(path = '/', opened = true) {
  const ctx = await b.newContext({ viewport: { width: 1440, height: 900 } });
  await ctx.addInitScript(() => { try { sessionStorage.setItem('rm.viewed', '1'); } catch {} });
  if (opened) await ctx.addInitScript(() => { if (!sessionStorage.getItem('x')) { localStorage.setItem('rm.opened', '1'); sessionStorage.setItem('x', '1'); } });
  const p = await ctx.newPage();
  p.on('console', (m) => { if (m.type() === 'error') errs.push(path + ' ' + m.text()); });
  p.on('pageerror', (e) => errs.push(path + ' pageerror ' + e.message));
  await p.goto(base + path, { waitUntil: 'networkidle' });
  return { ctx, p };
}

// 1. abertura na primeira visita
{
  const { ctx, p } = await page('/', false);
  ok('abertura aparece na 1ª visita', await p.isVisible('#opening'));
  await p.click('#open-silent'); await p.waitForTimeout(2200);
  ok('abertura some depois de abrir', !(await p.$('#opening')));
  await p.reload({ waitUntil: 'networkidle' });
  ok('abertura não volta na 2ª visita', !(await p.$('#opening')) || !(await p.isVisible('#opening')));
  await ctx.close();
}

// 2. mesa: ordem certa vence, ordem errada perde
{
  const { ctx, p } = await page('/');
  await p.evaluate(() => document.getElementById('play').scrollIntoView({ behavior: 'instant' }));
  await p.waitForSelector('#table[data-ready="1"]', { timeout: 10000 });
  const pick = async (ids) => { for (const id of ids) await p.click(`#hand button.card[data-idx="${id}"]`); };
  // mão: 0 Golpe, 1 Golpe Rápido (COMBO), 2 Defender, 3 Golpe
  await pick([1, 0, 3, 2]);
  const prev = await p.textContent('#foe-hp b');
  ok('prévia mostra 38 de dano com a ordem certa', /−38/.test(prev), prev);
  ok('combo anunciado (Saraivada/Par)', /\+/.test(await p.textContent('#callout')), await p.textContent('#callout'));
  await p.click('#t-end'); await p.waitForTimeout(2500);
  ok('ordem certa vence', /Victory|Vitória/i.test(await p.textContent('#t-log')), await p.textContent('#t-log'));
  await p.click('#t-reset'); await p.waitForTimeout(300);
  await pick([0, 3, 1, 2]);
  const prev2 = await p.textContent('#foe-hp b');
  ok('ordem errada dá 32', /−32/.test(prev2), prev2);
  await p.click('#t-end'); await p.waitForTimeout(2500);
  ok('ordem errada perde e dá a dica', /COMBO/.test(await p.textContent('#t-log')), (await p.textContent('#t-log')).slice(0, 90));
  await ctx.close();
}

// 2b. mesa no celular (390 px, alemão): tocar as cartas e o botão de encerrar sem nada por cima
{
  const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  await ctx.addInitScript(() => { localStorage.setItem('rm.opened', '1'); sessionStorage.setItem('rm.viewed', '1'); });
  const p = await ctx.newPage();
  await p.goto(base + '/de/', { waitUntil: 'networkidle' });
  await p.evaluate(() => document.getElementById('table').scrollIntoView({ behavior: 'instant' }));
  await p.waitForSelector('#table[data-ready="1"]');
  for (const i of [1, 0, 3, 2]) await p.tap(`#hand button.card[data-idx="${i}"]`, { timeout: 5000 });
  ok('celular: resumo de dano visível junto dos botões', /38/.test(await p.textContent('#t-sum')), await p.textContent('#t-sum'));
  await p.tap('#t-end', { timeout: 5000 }); await p.waitForTimeout(2500);
  ok('celular: Encerrar Turno tocável e vitória', /Sieg|Seite/i.test(await p.textContent('#t-log')), (await p.textContent('#t-log')).slice(0, 60));
  await ctx.close();
}

// 3. temas, segredos, Konami, embaralhar
{
  const { ctx, p } = await page('/');
  for (const id of ['fields', 'highlands', 'abyss', 'frost', 'marsh', 'dusk']) {
    await p.click(`.rune[data-biome="${id}"]`); await p.waitForTimeout(150);
    const cur = await p.evaluate(() => document.documentElement.dataset.biome);
    const bg = await p.evaluate(() => getComputedStyle(document.getElementById('castle')).backgroundImage);
    ok(`tema ${id}`, cur === id && bg.includes(id + '_castle'), bg.slice(-40));
  }
  ok('Eclipse escondido antes das runas', await p.$eval('.rune[data-biome="eclipse"]', (e) => e.hidden));
  // as 5 runas escondidas (a do bestiário fica no ato 6)
  await p.evaluate(() => { document.querySelector('#tab-dusk').click(); });
  for (let i = 1; i <= 5; i++) {
    await p.$eval(`.secret-rune[data-secret="${i}"]`, (e) => { e.scrollIntoView({ behavior: 'instant', block: 'center' }); });
    await p.click(`.secret-rune[data-secret="${i}"]`, { force: true }); await p.waitForTimeout(150);
  }
  ok('5 runas abrem o Eclipse', (await p.evaluate(() => document.documentElement.dataset.biome)) === 'eclipse' && !(await p.$eval('.rune[data-biome="eclipse"]', (e) => e.hidden)));
  ok('aviso com link para /eclipse/', !!(await p.$('#toast a[href="/eclipse/"]')));
  for (const k of ['ArrowUp', 'ArrowUp', 'ArrowDown', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'ArrowLeft', 'ArrowRight', 'b', 'a']) await p.keyboard.press(k);
  ok('Konami liga o CRT', await p.evaluate(() => document.body.classList.contains('crt-all')));
  await p.click('#shuffle'); await p.waitForTimeout(200);
  ok('Embaralhar mostra algo', (await p.textContent('#shuffle-out')).trim().length > 5);
  await p.click('#motion');
  ok('Reduzir movimento liga', await p.evaluate(() => document.body.classList.contains('reduced')));
  await ctx.close();
}

// 4. "Me avise" pela interface, e saída pelo link (limpa o teste)
{
  const { ctx, p } = await page('/pt/');
  await p.fill('#n2-e', 'teste-e2e@example.com');
  await p.click('#final form.notify button[type=submit]');
  await p.waitForSelector('#final form.notify .msg a', { timeout: 10000 });
  const href = await p.getAttribute('#final form.notify .msg a', 'href');
  ok('Me avise grava e devolve link de saída', /\/pt\/unsubscribe\/\?t=/.test(href));
  await p.goto(base + href, { waitUntil: 'networkidle' });
  await p.click('#unsub button'); await p.waitForTimeout(1500);
  ok('link de saída apaga o e-mail', /apagado|erased|Pronto/i.test(await p.textContent('#unsub .msg')), await p.textContent('#unsub .msg'));
  await ctx.close();
}

// 5. idiomas e páginas
for (const [path, word] of [['/', 'Bestiary'], ['/pt/', 'Bestiário'], ['/es/', 'Bestiario'], ['/fr/', 'Bestiaire'], ['/de/', 'Bestiarium'], ['/pt/privacy/', 'Privacidade'], ['/eclipse/', 'Eclipse'], ['/de/nichts', '']]) {
  const { ctx, p } = await page(path);
  const txt = await p.textContent('body');
  ok(`página ${path}`, word ? txt.includes(word) : true, word);
  await ctx.close();
}
const real = errs.filter((e) => !(e.startsWith('/de/nichts') && /404/.test(e))); // o 404 da página inexistente é esperado
ok('sem erros de console', real.length === 0, real.slice(0, 5).join(' | '));
await b.close();
const fail = results.filter((r) => !r.pass).length;
console.log(`\n${results.length - fail}/${results.length} PASS`);
process.exit(fail ? 1 : 0);
