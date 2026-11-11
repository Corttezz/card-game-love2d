// Teste de ponta a ponta da v3 (headless): tela de título nos 5 idiomas, cada painel, carta que vira, sair e reacender,
// teclado (setas, Esc, foco preso), "Me avise" com conquista e saída do e-mail de teste, privacidade e 404.
// uso: node tools/e2e.mjs [base]
import { chromium } from 'playwright-core';
const base = process.argv[2] || 'https://runemoire.com';
const b = await chromium.launch({ executablePath: 'C:/Users/corte/AppData/Local/ms-playwright/chromium_headless_shell-1254/chrome-headless-shell-win64/chrome-headless-shell.exe' });
const res = []; const errs = [];
const ok = (n, c, x = '') => { res.push(!!c); console.log(c ? 'PASS' : 'FAIL', n, x); };
const open = async (p, w = 1440, h = 900) => {
  const m = w < 600;
  const ctx = await b.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: m ? 3 : 1, isMobile: m, hasTouch: m });
  const pg = await ctx.newPage();
  pg.on('console', (x) => { if (x.type() === 'error' && !p.includes('nada') && !/api\/view/.test(x.text())) errs.push(p + ' ' + x.text()); });
  pg.on('pageerror', (e) => errs.push(p + ' ' + e.message));
  await pg.goto(base + p, { waitUntil: 'networkidle' }); await pg.waitForTimeout(600);
  if (await pg.isVisible('#screenhit')) { await pg.waitForTimeout(900); await pg.click('#screenhit'); await pg.waitForTimeout(1100); }
  return { ctx, pg };
};
{
  const ctx = await b.newContext({ viewport: { width: 1440, height: 900 } }); const pg = await ctx.newPage();
  await pg.goto(base + '/', { waitUntil: 'networkidle' }); await pg.waitForTimeout(1500);
  ok('abre no computador do jogo com a tela ligada', await pg.isVisible('#computer') && await pg.evaluate(() => document.documentElement.classList.contains('mode-desk') && !document.getElementById('tv').classList.contains('off')));
  ok('a tela dentro do monitor não recebe teclado', await pg.evaluate(() => document.getElementById('tv').hasAttribute('inert')));
  await ctx.close();
}
const LBL = { '/': 'PLAY', '/pt/': 'JOGAR', '/es/': 'JUGAR', '/fr/': 'JOUER', '/de/': 'SPIELEN' };
for (const [p, word] of Object.entries(LBL)) for (const w of [1440, 390]) {
  const { ctx, pg } = await open(p, w, w < 600 ? 844 : 900);
  const noScroll = await pg.evaluate(() => document.documentElement.scrollHeight <= innerHeight + 1 && document.documentElement.scrollWidth <= innerWidth + 1);
  ok(`título ${p} ${w}`, (await pg.textContent('.menu')).includes(word) && noScroll, word);
  await ctx.close();
}
{
  const { ctx, pg } = await open('/');
  for (const id of ['play', 'collection', 'achievements', 'settings']) {
    await pg.click(`.menu a[data-open="${id}"]`);
    ok(`painel ${id} abre`, await pg.isVisible(`#${id}.open`));
    await pg.keyboard.press('Escape');
    ok(`painel ${id} fecha com Esc`, !(await pg.isVisible(`#${id}.open`)));
  }
  await pg.click('.menu a[data-open="collection"]');
  ok('coleção mostra 4 cartas do jogo e 3 telas', (await pg.$$('#collection .cards img')).length === 4 && (await pg.$$('#collection .screens img')).length === 3);
  ok('fundo inerte com painel aberto', await pg.evaluate(() => document.getElementById('main').hasAttribute('inert')));
  await pg.keyboard.press('Escape');
  await pg.click('.menu a[data-open="play"]'); await pg.click('.vplay'); await pg.waitForTimeout(800);
  ok('trailer só carrega ao clicar', !!(await pg.$('#play video')));
  await pg.keyboard.press('Escape');
  await pg.click('.hang.left', { force: true }); await pg.waitForTimeout(800);
  const src = await pg.getAttribute('.hang.left .f', 'src');
  ok('carta flutuante vira e mostra carta do jogo', (await pg.getAttribute('.hang.left', 'aria-pressed')) === 'true' && /\/img\/gamecards\/en\//.test(src), src);
  await pg.focus('.menu a[data-open="play"]'); await pg.keyboard.press('ArrowDown');
  ok('setas movem a seleção do menu', await pg.evaluate(() => document.activeElement?.getAttribute('data-open') === 'collection'));
  await pg.click('.menu a[data-open="quit"]'); await pg.waitForTimeout(1200);
  ok('sair desliga a TV e volta ao computador', await pg.evaluate(() => document.documentElement.classList.contains('mode-desk') && document.getElementById('tv').classList.contains('off')));
  await pg.click('#screenhit'); await pg.waitForTimeout(1200);
  ok('clicar na tela apagada liga a TV', await pg.evaluate(() => !document.getElementById('tv').classList.contains('off')));
  await pg.click('#screenhit'); await pg.waitForTimeout(1200);
  ok('clicar de novo mergulha na tela cheia', await pg.evaluate(() => document.documentElement.classList.contains('mode-full') && !document.getElementById('tv').hasAttribute('inert')));
  await pg.click('.menu a[data-open="settings"]'); await pg.click('#opt-crt');
  ok('opção CRT desliga', !(await pg.evaluate(() => document.body.classList.contains('crt'))));
  await pg.click('#opt-motion');
  ok('opção movimento reduzido liga', await pg.evaluate(() => document.body.classList.contains('reduced')));
  await ctx.close();
}
{
  const { ctx, pg } = await open('/pt/');
  await pg.click('.menu a[data-open="achievements"]');
  await pg.fill('#email', 'teste-v3@example.com'); await pg.click('#achievements form button[type=submit]');
  await pg.waitForSelector('#toast.in', { timeout: 10000 }).catch(() => {});
  ok('conquista: toast do jogo e ícone desbloqueado', await pg.isVisible('#toast') && /ach\.(png|webp)$/.test(await pg.getAttribute('#ach-icon', 'src')));
  const href = await pg.getAttribute('#achievements .msg a', 'href').catch(() => null);
  ok('Me avise devolve link de saída', /\/pt\/unsubscribe\/\?t=/.test(href || ''), href || '');
  if (href) { await pg.goto(base + href, { waitUntil: 'networkidle' }); await pg.click('#unsub button'); await pg.waitForTimeout(1500); ok('saída apaga o e-mail de teste', /apagado/i.test(await pg.textContent('#unsub .msg'))); }
  await ctx.close();
}
for (const [p, sel] of [['/pt/privacy/', '.prose h1'], ['/de/nada', '#quit[data-static]']]) {
  const { ctx, pg } = await open(p);
  ok(`página ${p}`, !!(await pg.$(sel)));
  await ctx.close();
}
ok('sem erros de console', errs.length === 0, errs.slice(0, 3).join(' | '));
await b.close();
const f = res.filter((x) => !x).length; console.log(`\n${res.length - f}/${res.length} PASS`); process.exit(f ? 1 : 0);
