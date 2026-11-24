// Teste de ponta a ponta da v3b (headless, WebGL por SwiftShader): o computador começa desligado; um clique roda a abertura
// inteira do jogo (carta, tubo liga, nome, clarão, mergulho, TV liga, carregando, selo, logo) até a tela de título;
// cliques/teclas pulam como no jogo; 5 idiomas; painéis; carta que vira; sair desliga a TV e volta ao computador;
// opções; "Me avise" com conquista e saída do e-mail de teste; privacidade e 404.
// uso: node tools/e2e.mjs [base]
import { chromium } from 'playwright-core';
const base = process.argv[2] || 'https://runemoire.com';
const b = await chromium.launch({ executablePath: 'C:/Users/corte/AppData/Local/ms-playwright/chromium_headless_shell-1254/chrome-headless-shell-win64/chrome-headless-shell.exe', args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const res = []; const errs = [];
const ok = (n, c, x = '') => { res.push(!!c); console.log(c ? 'PASS' : 'FAIL', n, x); };
const isMenu = (pg) => pg.evaluate(() => document.documentElement.classList.contains('in-menu'));
const inMenu = (pg, t = 15000) => pg.waitForFunction(() => document.documentElement.classList.contains('in-menu'), null, { timeout: t }).then(() => true).catch(() => false);
// abre e pula a abertura como um jogador impaciente: clique (insere) e mais teclas (pulam)
const open = async (p, w = 1440, h = 900, skip = true) => {
  const m = w < 600;
  const ctx = await b.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: m ? 3 : 1, isMobile: m, hasTouch: m });
  const pg = await ctx.newPage();
  pg.on('console', (x) => { if (x.type() === 'error' && !p.includes('nada') && !/api\/view/.test(x.text())) errs.push(p + ' ' + x.text()); });
  pg.on('pageerror', (e) => errs.push(p + ' ' + e.message));
  await pg.goto(base + p, { waitUntil: 'networkidle' }); await pg.waitForTimeout(500);
  if (skip && await pg.isVisible('#screenhit')) {
    await pg.click('#screenhit');
    for (let i = 0; i < 8 && !(await isMenu(pg)); i++) { await pg.waitForTimeout(400); await pg.keyboard.press('Space'); }
    await inMenu(pg);
  }
  return { ctx, pg };
};
{
  const { ctx, pg } = await open('/pt/', 1440, 900, false);
  await pg.waitForTimeout(900);
  ok('abre com o computador DESLIGADO e só a dica "CLIQUE NA TELA"', await pg.evaluate(() => window.__rm.mode === 'intro' && window.__rm.intro.phase === 'off' && !document.documentElement.classList.contains('on-crt')) && (await pg.textContent('#hint')).trim() === 'CLIQUE NA TELA');
  const t0 = Date.now();
  await pg.click('#screenhit');
  ok('um clique roda a abertura inteira até o menu', await inMenu(pg, 45000), `${((Date.now() - t0) / 1000).toFixed(1)} s`);
  const ph = await pg.evaluate(() => window.__rmPhases.join(','));
  ok('passos na ordem: carta, tubo liga, nome, clarão, zoom, TV liga, menu', ph === 'insert,power,type,flash,dive,boot,menu', ph);
  ok('menu com o CRT do jogo (WebGL)', await pg.evaluate(() => window.__rm.glOk && window.__rm.crtOn && window.__rm.crt.power > 0.99 && getComputedStyle(document.getElementById('crt')).display === 'block'));
  await ctx.close();
}
const LBL = { '/': 'PLAY', '/pt/': 'JOGAR', '/es/': 'JUGAR', '/fr/': 'JOUER', '/de/': 'SPIELEN' };
for (const [p, word] of Object.entries(LBL)) for (const w of [1440, 390]) {
  const { ctx, pg } = await open(p, w, w < 600 ? 844 : 900);
  // a cena ocupa a primeira tela inteira; o texto (SEO) só começa depois dela, sem rolagem lateral
  const noScroll = await pg.evaluate(() => scrollY === 0 && document.documentElement.scrollWidth <= innerWidth + 1 && document.getElementById('main').getBoundingClientRect().top >= innerHeight - 1);
  const live = await pg.evaluate(() => document.documentElement.classList.contains('in-menu') && !document.getElementById('title').hasAttribute('inert'));
  ok(`pular com clique/tecla e chegar ao título ${p} ${w}`, live && (await pg.textContent('.menu')).includes(word) && noScroll, word);
  await ctx.close();
}
{
  const { ctx, pg } = await open('/');
  for (const id of ['play', 'achievements', 'settings']) {
    await pg.click(`.menu a[data-open="${id}"]`, { force: true });
    ok(`painel ${id} abre`, await pg.isVisible(`#${id}.open`));
    await pg.keyboard.press('Escape');
    ok(`painel ${id} fecha com Esc`, !(await pg.isVisible(`#${id}.open`)));
  }
  await pg.click('.menu a[data-open="settings"]', { force: true });
  ok('sem a aba Coleção', !(await pg.$('#collection')) && !(await pg.$('.menu a[data-open="collection"]')));
  ok('fundo inerte com painel aberto', await pg.evaluate(() => document.getElementById('title').hasAttribute('inert')));
  await pg.keyboard.press('Escape');
  // texto visível depois da cena: H1, trailer em <video>, link externo; o "Me avise" de lá abre o painel
  await pg.evaluate(() => document.getElementById('main').scrollIntoView());
  ok('texto depois da cena visível com H1 e trailer', await pg.isVisible('#main h1') && await pg.isVisible('#main video') && !!(await pg.$('#main a[href="https://dcsolutions.app/"]')));
  await pg.click('#main a[data-open="achievements"]');
  ok('Me avise do texto abre o painel', await pg.isVisible('#achievements.open'));
  await pg.keyboard.press('Escape'); await pg.evaluate(() => scrollTo(0, 0));
  await pg.click('.menu a[data-open="play"]', { force: true }); await pg.click('.vplay'); await pg.waitForTimeout(800);
  ok('trailer só carrega ao clicar', !!(await pg.$('#play video')));
  await pg.keyboard.press('Escape');
  await pg.hover('.menu a[data-open="achievements"]', { force: true }); await pg.waitForTimeout(100);
  ok('passar o mouse acende o botão do jogo', await pg.evaluate(() => window.__rm.menu.hover === 'achievements'));
  await pg.click('.hang[data-i="0"]', { force: true }); await pg.waitForTimeout(900);
  const src = await pg.evaluate(() => window.__rm.menu.cards[0].face?.src || '');
  ok('carta flutuante vira e mostra carta do jogo', (await pg.getAttribute('.hang[data-i="0"]', 'aria-pressed')) === 'true' && /\/img\/gamecards\/en\//.test(src), src);
  await pg.focus('.menu a[data-open="play"]'); await pg.keyboard.press('ArrowDown');
  ok('setas movem a seleção do menu', await pg.evaluate(() => document.activeElement?.getAttribute('data-open') === 'achievements'));
  await pg.click('.menu a[data-open="quit"]', { force: true });
  await pg.waitForTimeout(300);
  ok('sair: a TV desliga pelo shader (powerOff)', await pg.evaluate(() => window.__rm.crt.dir === -1 && window.__rm.crt.power < 1));
  await pg.waitForTimeout(1400);
  ok('e volta ao computador desligado', await pg.evaluate(() => window.__rm.mode === 'intro' && window.__rm.intro.phase === 'off' && !document.documentElement.classList.contains('on-crt')));
  await pg.click('#screenhit'); await pg.waitForTimeout(300);
  ok('clicar de novo insere a carta outra vez', await pg.evaluate(() => window.__rm.intro.phase === 'insert'));
  for (let i = 0; i < 8 && !(await isMenu(pg)); i++) { await pg.keyboard.press('Enter'); await pg.waitForTimeout(400); }
  ok('teclas pulam até o menu', await inMenu(pg));
  await pg.click('.menu a[data-open="settings"]', { force: true });
  ok('opções só idioma e música (sem SFX, CRT e movimento reduzido)', !!(await pg.$('#settings .langs')) && !!(await pg.$('#opt-music')) && !(await pg.$('#opt-sfx')) && !(await pg.$('#opt-crt')) && !(await pg.$('#opt-motion')));
  await ctx.close();
}
{
  const { ctx, pg } = await open('/pt/');
  await pg.click('.menu a[data-open="achievements"]', { force: true });
  await pg.fill('#email', 'teste-v3b@example.com'); await pg.click('#achievements form button[type=submit]');
  await pg.waitForSelector('#toast.in', { timeout: 10000 }).catch(() => {});
  ok('conquista: toast do jogo e ícone desbloqueado', await pg.isVisible('#toast') && /ach\.(png|webp)$/.test(await pg.getAttribute('#ach-icon', 'src')));
  const href = await pg.getAttribute('#achievements .msg a', 'href').catch(() => null);
  ok('Me avise devolve link de saída', /\/pt\/unsubscribe\/\?t=/.test(href || ''), href || '');
  if (href) { await pg.goto(base + href, { waitUntil: 'networkidle' }); await pg.click('#unsub button'); await pg.waitForTimeout(1500); ok('saída apaga o e-mail de teste', /apagado/i.test(await pg.textContent('#unsub .msg'))); }
  await ctx.close();
}
{
  const { ctx, pg } = await open('/pt/privacy/', 1440, 900, false);
  ok('página /pt/privacy/', !!(await pg.$('.prose h1')));
  await ctx.close();
}
{
  const { ctx, pg } = await open('/de/nada', 1440, 900, false);
  ok('404: computador desligado, frase e volta', !!(await pg.$('.nfback')) && (await pg.textContent('#hint')).length > 5 && await pg.evaluate(() => window.__rm.intro.phase === 'off'));
  await ctx.close();
}
ok('sem erros de console', errs.length === 0, errs.slice(0, 3).join(' | '));
await b.close();
const f = res.filter((x) => !x).length; console.log(`\n${res.length - f}/${res.length} PASS`); process.exit(f ? 1 : 0);
